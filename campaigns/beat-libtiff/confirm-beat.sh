#!/usr/bin/env bash
# confirm-beat.sh — file-hash disagree + sanitizers silent
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/campaigns/common/campaign-env.sh"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"

CAMP="${ROOT}/campaigns/beat-libtiff"
OUT="${ROOT}/reports/live/beat-libtiff"
DIFFS="${OUT}/cdub_diffs"
CONF="${OUT}/confirmed"
OUT_FILE="out.file"
mkdir -p "$CONF"

T0="${CAMP}/cdub-bin/tiffcp-0"
T1="${CAMP}/cdub-bin/tiffcp-1"
ASAN="${CAMP}/san-bin/tiffcp-asan"
UBSAN="${CAMP}/san-bin/tiffcp-ubsan"
MSAN="${CAMP}/san-bin/tiffcp-msan"

BEAT_COUNT=0
CANDIDATES=0

run_pair() {
  local inp="$1" d="$2"
  rm -f "$d/out0.file" "$d/out1.file"
  timeout 10 "$T0" -M -i "$inp" "$d/out0.file" >"$d/err0.txt" 2>&1 || true
  timeout 10 "$T1" -M -i "$inp" "$d/out1.file" >"$d/err1.txt" 2>&1 || true
}

confirm_one() {
  local inp="$1"
  local id
  id="$(basename "$inp" | tr ',' '_' | head -c 80)"
  local d="${CONF}/$id"
  mkdir -p "$d"
  cp -f "$inp" "$d/input"
  run_pair "$inp" "$d"

  local disagree=0
  if [ -f "$d/out0.file" ] && [ -f "$d/out1.file" ]; then
    cmp -s "$d/out0.file" "$d/out1.file" || disagree=1
  else
    cmp -s "$d/err0.txt" "$d/err1.txt" || disagree=1
  fi

  local san_hit=0
  for exe in "$ASAN" "$UBSAN" "$MSAN"; do
    [ -x "$exe" ] || continue
    set +e
    timeout 10 "$exe" -M -i "$inp" "$d/san-$(basename "$exe").file" \
      >"$d/san-$(basename "$exe").txt" 2>&1
    local rc=$?
    set -e
    local t
    t="$(cat "$d/san-$(basename "$exe").txt" 2>/dev/null || true)"
    if [ "$rc" -lt 0 ] || [ "$rc" -ge 128 ]; then
      san_hit=1
    fi
    if echo "$t" | grep -qiE 'sanitizer|runtime error|SUMMARY:|heap-|stack-|memorysanitizer'; then
      san_hit=1
    fi
  done

  local stable=1
  local h0 h1
  if [ -f "$d/out0.file" ] && [ -f "$d/out1.file" ]; then
    h0="$(sha256sum "$d/out0.file" | awk '{print $1}')"
    h1="$(sha256sum "$d/out1.file" | awk '{print $1}')"
    for i in 1 2 3; do
      run_pair "$inp" "$d"
      [ -f "$d/out0.file" ] || { stable=0; break; }
      [ -f "$d/out1.file" ] || { stable=0; break; }
      [ "$(sha256sum "$d/out0.file" | awk '{print $1}')" = "$h0" ] || stable=0
      [ "$(sha256sum "$d/out1.file" | awk '{print $1}')" = "$h1" ] || stable=0
    done
  fi

  {
    sha256sum "$T0" "$T1" "$d/input" 2>/dev/null || true
    [ -f "$d/out0.file" ] && sha256sum "$d/out0.file"
    [ -f "$d/out1.file" ] && sha256sum "$d/out1.file"
  } >"$d/SHA256.txt"

  local triage=NOISE
  if [ "$disagree" -eq 1 ] && [ "$san_hit" -eq 0 ] && [ "$stable" -eq 1 ]; then
    triage=PROGRAM_UB
    BEAT_COUNT=$((BEAT_COUNT + 1))
    echo "BEAT id=$id triage=$triage" | tee -a "${OUT}/beats.txt"
  fi

  echo "id=$id disagree=$disagree san_hit=$san_hit stable=$stable triage=$triage" \
    | tee -a "${OUT}/confirm_log.txt"
  printf '%s\n' "disagree=$disagree" "san_hit=$san_hit" "stable=$stable" "triage=$triage" >"$d/meta.env"
}

: >"${OUT}/beats.txt"
: >"${OUT}/confirm_log.txt"

if [ -d "$DIFFS" ]; then
  for f in "$DIFFS"/*; do
    [ -f "$f" ] || continue
    CANDIDATES=$((CANDIDATES + 1))
    confirm_one "$f"
  done
fi

# Extended scan: corpus + AFL queue
if [ -x "$T0" ] && [ -x "$T1" ]; then
  python3 - <<'PY'
import json, pathlib, subprocess, hashlib, tempfile, os
out = pathlib.Path("/opt/cd-ub/reports/live/beat-libtiff")
camp = pathlib.Path("/opt/cd-ub/campaigns/beat-libtiff")
t0 = camp / "cdub-bin/tiffcp-0"
t1 = camp / "cdub-bin/tiffcp-1"
asan = camp / "san-bin/tiffcp-asan"
ubsan = camp / "san-bin/tiffcp-ubsan"
msan = camp / "san-bin/tiffcp-msan"
candidates = []
bp = out / "sanitizer_baseline.json"
if bp.exists():
    for seed in json.loads(bp.read_text()).get("google_pass_seeds", [])[:80]:
        p = pathlib.Path(seed)
        if p.exists():
            candidates.append(p)
qdir = out / "findings/default/queue"
if qdir.is_dir():
    qs = sorted(qdir.iterdir())
    for p in qs[:100] + qs[-100:]:
        if p.is_file() and p.stat().st_size < 500_000:
            candidates.append(p)
seen = set()
uniq = []
for p in candidates:
    h = hashlib.sha256(p.read_bytes()).hexdigest()
    if h in seen:
        continue
    seen.add(h)
    uniq.append(p)

def run_pair(exe, path, outf):
    try:
        r = subprocess.run([str(exe), "-M", "-i", str(path), str(outf)],
                           capture_output=True, text=True, timeout=10)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except Exception as e:
        return 99, str(e)

def file_hash(path):
  if not path.exists():
    return None
  return hashlib.sha256(path.read_bytes()).hexdigest()

beats_extra = 0
scanned = 0
for p in uniq:
    scanned += 1
    with tempfile.TemporaryDirectory() as td:
        td = pathlib.Path(td)
        o0 = td / "o0.file"
        o1 = td / "o1.file"
        rc0, t0txt = run_pair(t0, p, o0)
        rc1, t1txt = run_pair(t1, p, o1)
        h0 = file_hash(o0)
        h1 = file_hash(o1)
        if h0 and h1 and h0 == h1:
            continue
        if not h0 and not h1 and t0txt == t1txt:
            continue
        san_hit = False
        for exe in (asan, ubsan, msan):
            if not exe.exists():
                continue
            so = td / "san.file"
            rc, txt = run_pair(exe, p, so)
            if rc < 0 or rc >= 128:
                san_hit = True
            if any(k in txt.lower() for k in ("sanitizer", "runtime error", "summary:", "heap-", "stack-", "memorysanitizer")):
                san_hit = True
        if san_hit:
            continue
        stable = True
        for _ in range(3):
            with tempfile.TemporaryDirectory() as td2:
                td2 = pathlib.Path(td2)
                r0 = td2 / "r0.file"
                r1 = td2 / "r1.file"
                run_pair(t0, p, r0)
                run_pair(t1, p, r1)
                if file_hash(r0) != h0 or file_hash(r1) != h1:
                    stable = False
        if not stable:
            continue
        beats_extra += 1
        d = out / "confirmed" / f"scanbeat-{p.name.replace(',', '_')[:80]}"
        d.mkdir(parents=True, exist_ok=True)
        (d / "input").write_bytes(p.read_bytes())
        if o0.exists():
            (d / "out0.file").write_bytes(o0.read_bytes())
        if o1.exists():
            (d / "out1.file").write_bytes(o1.read_bytes())
        (d / "meta.env").write_text("disagree=1\nsan_hit=0\nstable=1\ntriage=PROGRAM_UB\n")
        with (out / "beats.txt").open("a") as f:
            f.write(f"BEAT id=scanbeat-{p.name} triage=PROGRAM_UB\n")
print(f"SCANNED={scanned}")
print(f"SEED_SCAN_EXTRA_BEATS={beats_extra}")
(out / "seed_scan_extra.txt").write_text(str(beats_extra))
(out / "seed_scan_scanned.txt").write_text(str(scanned))
PY
  EXTRA="$(cat "${OUT}/seed_scan_extra.txt" 2>/dev/null || echo 0)"
  BEAT_COUNT=$((BEAT_COUNT + EXTRA))
fi

echo "CANDIDATES=$CANDIDATES" | tee "${OUT}/confirm_summary.txt"
echo "BEAT_COUNT=$BEAT_COUNT" | tee -a "${OUT}/confirm_summary.txt"
echo "$BEAT_COUNT" >"${OUT}/BEAT_COUNT.txt"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "CONFIRM_DONE"
