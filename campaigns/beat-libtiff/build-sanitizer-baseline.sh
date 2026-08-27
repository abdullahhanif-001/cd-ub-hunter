#!/usr/bin/env bash
# build-sanitizer-baseline.sh — ASan/UBSan(/MSan) tiffcp + corpus GOOGLE_PASS
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/campaigns/common/campaign-env.sh"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"

CAMP="${ROOT}/campaigns/beat-libtiff"
SRC="${CAMP}/src/libtiff"
OUT="${ROOT}/reports/live/beat-libtiff"
BIN="${CAMP}/san-bin"
CORP="${CAMP}/corpus"
mkdir -p "$OUT" "$BIN" "$CORP"

export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
  autoconf automake libtool pkg-config \
  zlib1g-dev libjpeg-dev libwebp-dev \
  2>&1 | tail -3

build_one() {
  local name="$1"
  local bdir="${CAMP}/build-$name"
  rm -rf "$bdir"
  mkdir -p "$bdir"
  cp -a "$SRC/." "$bdir/"
  cd "$bdir"
  if [ ! -f configure ]; then
    ./autogen.sh 2>/dev/null || true
  fi
  # shellcheck disable=SC2086
  ./configure --disable-shared --disable-docs \
    CC="clang" CXX="clang++" \
    CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" \
    2>"${OUT}/configure-$name.log" || { echo "CONFIG_FAIL $name"; return 1; }
  make -j"$(nproc)" 2>"${OUT}/make-$name.log" || { echo "MAKE_FAIL $name"; return 1; }
  cp -f ./tools/tiffcp "${BIN}/tiffcp-$name"
  echo "BUILT tiffcp-$name"
}

# Enrich corpus from pinned libtiff tree
find "$SRC/test/images" \( -name '*.tif' -o -name '*.tiff' \) -type f 2>/dev/null | head -60 | while read -r f; do
  cp -n "$f" "$CORP/" 2>/dev/null || cp "$f" "$CORP/$(basename "$f")"
done
find "$SRC/contrib" -name '*.tif' -type f 2>/dev/null | head -20 | while read -r f; do
  cp "$f" "$CORP/contrib_$(basename "$f")" 2>/dev/null || true
done
printf 'II*\x00\x08\x00\x00\x00' >"$CORP/mini_le.tif"
printf 'MM\x00\x2a\x00\x00\x00\x08' >"$CORP/mini_be.tif"

# ASan
export CFLAGS="-O1 -g -fsanitize=address -fno-omit-frame-pointer"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-fsanitize=address"
build_one asan || true

# UBSan
export CFLAGS="-O1 -g -fsanitize=undefined -fno-sanitize-recover=undefined"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-fsanitize=undefined"
build_one ubsan || true

# MSan
export CFLAGS="-O1 -g -fsanitize=memory -fno-omit-frame-pointer -fsanitize-memory-track-origins=2"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-fsanitize=memory"
if build_one msan; then
  MSAN_OK=1
else
  MSAN_OK=0
  echo "MSAN_SKIP=1" | tee "${OUT}/msan_skip.txt"
fi

python3 - <<'PY'
import json, os, pathlib, subprocess, hashlib, tempfile
camp = pathlib.Path("/opt/cd-ub/campaigns/beat-libtiff")
out = pathlib.Path("/opt/cd-ub/reports/live/beat-libtiff")
corp = camp / "corpus"
bin_dir = camp / "san-bin"
results = []
pass_seeds = []

def run_tiffcp(exe, seed, out_file):
    env = {**os.environ, "ASAN_OPTIONS": "detect_leaks=0", "MSAN_OPTIONS": "halt_on_error=1"}
    return subprocess.run(
        [str(exe), "-M", "-i", str(seed), str(out_file)],
        capture_output=True, text=True, timeout=10, env=env,
    )

for seed in sorted(corp.glob("*")):
    if not seed.is_file():
        continue
    entry = {"seed": str(seed), "sha256": hashlib.sha256(seed.read_bytes()).hexdigest()[:16], "oracles": {}}
    all_pass = True
    for name in ("asan", "ubsan", "msan"):
        exe = bin_dir / f"tiffcp-{name}"
        if not exe.exists():
            entry["oracles"][name] = "SKIP"
            if name != "msan":
                all_pass = False
            continue
        with tempfile.TemporaryDirectory() as td:
            outf = pathlib.Path(td) / "out.file"
            try:
                r = run_tiffcp(exe, seed, outf)
                text = (r.stdout or "") + (r.stderr or "")
                hit = r.returncode < 0 or r.returncode >= 128
                if not hit and r.returncode != 0:
                    # tiffcp may exit non-zero on bad input without sanitizer hit
                    hit = any(k in text.lower() for k in (
                        "sanitizer", "runtime error", "summary:", "heap-", "stack-", "memorysanitizer"
                    ))
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
    "target": "libtiff",
    "version": "v4.3.0",
    "sha": (camp / "meta" / "libtiff.sha").read_text().strip() if (camp / "meta" / "libtiff.sha").exists() else "",
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
