#!/usr/bin/env bash
# build-sanitizer-baseline.sh — ASan/UBSan(/MSan) jq + corpus GOOGLE_PASS
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/campaigns/common/campaign-env.sh"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"

CAMP="${ROOT}/campaigns/beat-google"
SRC="${CAMP}/src/jq"
OUT="${ROOT}/reports/live/beat-google"
BIN="${CAMP}/san-bin"
CORP="${CAMP}/corpus"
mkdir -p "$OUT" "$BIN" "$CORP"

export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
  autoconf automake libtool flex bison python3 \
  2>&1 | tail -3

build_one() {
  local name="$1"
  shift
  local bdir="${CAMP}/build-$name"
  rm -rf "$bdir"
  mkdir -p "$bdir"
  # copy tree to avoid polluting src
  cp -a "$SRC/." "$bdir/"
  cd "$bdir"
  if [ ! -f configure ]; then
    autoreconf -i 2>/dev/null || true
    if [ -f configure.ac ] && [ ! -f configure ]; then
      autoreconf -fi
    fi
  fi
  # shellcheck disable=SC2086
  ./configure --disable-shared --disable-docs "$@" CC="clang" CXX="clang++" \
    CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" \
    2>"${OUT}/configure-$name.log" || {
      echo "CONFIG_FAIL $name"; return 1;
    }
  make -j"$(nproc)" 2>"${OUT}/make-$name.log" || {
      echo "MAKE_FAIL $name"; return 1;
  }
  cp -f ./jq "${BIN}/jq-$name"
  echo "BUILT jq-$name"
}

# Seed corpus: small JSON + jq test snippets
find "$SRC" -name '*.json' 2>/dev/null | head -40 | while read -r f; do
  cp -n "$f" "$CORP/" 2>/dev/null || true
done
printf '%s\n' '{"a":1}' '{"x":[1,2,3]}' 'null' 'true' '[1,2,3]' >"$CORP/mini1.json"
echo '{"k":"v"}' >"$CORP/mini2.json"

# ASan
export CFLAGS="-O1 -g -fsanitize=address -fno-omit-frame-pointer"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-fsanitize=address"
build_one asan --with-oniguruma=builtin || true

# UBSan
export CFLAGS="-O1 -g -fsanitize=undefined -fno-sanitize-recover=undefined"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-fsanitize=undefined"
build_one ubsan --with-oniguruma=builtin || true

# MSan (may fail without full libc instrumentation)
export CFLAGS="-O1 -g -fsanitize=memory -fno-omit-frame-pointer -fsanitize-memory-track-origins=2"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-fsanitize=memory"
if build_one msan --with-oniguruma=builtin; then
  MSAN_OK=1
else
  MSAN_OK=0
  echo "MSAN_SKIP=1" | tee "${OUT}/msan_skip.txt"
fi

# Run corpus — GOOGLE_PASS if no sanitizer report
python3 - <<'PY'
import json, os, pathlib, subprocess, hashlib
camp = pathlib.Path("/opt/cd-ub/campaigns/beat-google")
out = pathlib.Path("/opt/cd-ub/reports/live/beat-google")
corp = camp / "corpus"
bin_dir = camp / "san-bin"
results = []
pass_seeds = []
for seed in sorted(corp.glob("*")):
    if not seed.is_file():
        continue
    entry = {"seed": str(seed), "sha256": hashlib.sha256(seed.read_bytes()).hexdigest()[:16], "oracles": {}}
    all_pass = True
    for name in ("asan", "ubsan", "msan"):
        exe = bin_dir / f"jq-{name}"
        if not exe.exists():
            entry["oracles"][name] = "SKIP"
            if name != "msan":
                all_pass = False
            continue
        # jq '.' file  — identity filter, deterministic
        try:
            r = subprocess.run(
                [str(exe), ".", str(seed)],
                capture_output=True, text=True, timeout=5,
                env={**os.environ, "ASAN_OPTIONS": "detect_leaks=0", "MSAN_OPTIONS": "halt_on_error=1"},
            )
            text = (r.stdout or "") + (r.stderr or "")
            hit = r.returncode != 0 or any(
                k in text.lower() for k in ("sanitizer", "runtime error", "summary:", "heap-", "stack-")
            )
            entry["oracles"][name] = "HIT" if hit else "PASS"
            if hit:
                all_pass = False
        except Exception as e:
            entry["oracles"][name] = f"ERR:{e}"
            all_pass = False
    entry["GOOGLE_PASS"] = bool(all_pass)
    if all_pass:
        pass_seeds.append(str(seed))
    results.append(entry)

report = {
    "target": "jq",
    "sha": (camp / "meta" / "jq.sha").read_text().strip() if (camp / "meta" / "jq.sha").exists() else "",
    "corpus_n": len(results),
    "google_pass_n": len(pass_seeds),
    "google_pass_seeds": pass_seeds,
    "results": results,
    "MOCK_PCT": 0,
}
(out / "sanitizer_baseline.json").write_text(json.dumps(report, indent=2))
print(json.dumps({"corpus_n": report["corpus_n"], "google_pass_n": report["google_pass_n"]}, indent=2))
PY

bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "SANITIZER_BASELINE_OK"
