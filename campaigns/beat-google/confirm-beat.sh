#!/usr/bin/env bash
# confirm-beat.sh — for each filtered diff: CD-UB disagree + sanitizers silent
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/config/ephemeral.env" 2>/dev/null || true
bash "${ROOT}/deploy/contabo/pm2-guard.sh"

CAMP="${ROOT}/campaigns/beat-google"
OUT="${ROOT}/reports/live/beat-google"
DIFFS="${OUT}/cdub_diffs"
CONF="${OUT}/confirmed"
mkdir -p "$CONF"

JQ0="${CAMP}/cdub-bin/jq-0"
JQ1="${CAMP}/cdub-bin/jq-1"
ASAN="${CAMP}/san-bin/jq-asan"
UBSAN="${CAMP}/san-bin/jq-ubsan"
MSAN="${CAMP}/san-bin/jq-msan"

BEAT_COUNT=0
CANDIDATES=0

confirm_one() {
  local inp="$1"
  local id
  id="$(basename "$inp")"
  local d="${CONF}/$id"
  mkdir -p "$d"
  cp -f "$inp" "$d/input"
  timeout 3 "$JQ0" "." "$inp" >"$d/out0.txt" 2>&1 || echo "EXIT:$?" >>"$d/out0.txt"
  timeout 3 "$JQ1" "." "$inp" >"$d/out1.txt" 2>&1 || echo "EXIT:$?" >>"$d/out1.txt"
  local disagree=0
  cmp -s "$d/out0.txt" "$d/out1.txt" || disagree=1

  local san_hit=0
  for exe in "$ASAN" "$UBSAN" "$MSAN"; do
    [ -x "$exe" ] || continue
    set +e
    timeout 3 "$exe" "." "$inp" >"$d/san-$(basename "$exe").txt" 2>&1
    local rc=$?
    set -e
    local t
    t="$(cat "$d/san-$(basename "$exe").txt" 2>/dev/null || true)"
    if [ "$rc" -ne 0 ] || echo "$t" | grep -qiE 'sanitizer|runtime error|SUMMARY:|heap-|stack-'; then
      san_hit=1
    fi
  done

  # Reproducibility ×3
  local stable=1
  for i in 1 2 3; do
    timeout 3 "$JQ0" "." "$inp" >"$d/r0-$i.txt" 2>&1 || true
    timeout 3 "$JQ1" "." "$inp" >"$d/r1-$i.txt" 2>&1 || true
    cmp -s "$d/out0.txt" "$d/r0-$i.txt" || stable=0
    cmp -s "$d/out1.txt" "$d/r1-$i.txt" || stable=0
  done

  sha256sum "$JQ0" "$JQ1" "$d/out0.txt" "$d/out1.txt" "$d/input" >"$d/SHA256.txt"

  local triage=NOISE
  if [ "$disagree" -eq 1 ] && [ "$san_hit" -eq 0 ] && [ "$stable" -eq 1 ]; then
    triage=PROGRAM_UB
    # Heuristic: eval-order-like numeric permutation in outputs
    if grep -qE '^[0-9.[:space:]\{\}\[\]",:]+$' "$d/out0.txt" 2>/dev/null; then
      triage=PROGRAM_UB
    fi
    BEAT_COUNT=$((BEAT_COUNT + 1))
    echo "BEAT id=$id triage=$triage" | tee -a "${OUT}/beats.txt"
  fi

  echo "id=$id disagree=$disagree san_hit=$san_hit stable=$stable triage=$triage" \
    | tee -a "${OUT}/confirm_log.txt"
  printf '%s\n' "disagree=$disagree" "san_hit=$san_hit" "stable=$stable" "triage=$triage" >"$d/meta.env"
}

: >"${OUT}/beats.txt"
: >"${OUT}/confirm_log.txt"

if [ ! -d "$DIFFS" ] || [ -z "$(ls -A "$DIFFS" 2>/dev/null || true)" ]; then
  echo "NO_DIFFS_TO_CONFIRM"
else
  for f in "$DIFFS"/*; do
    [ -f "$f" ] || continue
    CANDIDATES=$((CANDIDATES + 1))
    confirm_one "$f"
  done
fi

# Probe GOOGLE_PASS seeds + AFL queue sample for CD-UB disagreement
if [ -x "$JQ0" ] && [ -x "$JQ1" ]; then
  python3 - <<'PY'
import json, pathlib, subprocess, hashlib
out = pathlib.Path("/opt/cd-ub/reports/live/beat-google")
camp = pathlib.Path("/opt/cd-ub/campaigns/beat-google")
jq0 = camp / "cdub-bin/jq-0"
jq1 = camp / "cdub-bin/jq-1"
asan = camp / "san-bin/jq-asan"
ubsan = camp / "san-bin/jq-ubsan"
msan = camp / "san-bin/jq-msan"
candidates = []
bp = out / "sanitizer_baseline.json"
if bp.exists():
    base = json.loads(bp.read_text())
    for seed in base.get("google_pass_seeds", [])[:40]:
        p = pathlib.Path(seed)
        if p.exists():
            candidates.append(p)
qdir = out / "findings/default/queue"
if qdir.is_dir():
    # Cap: first 80 + last 80 queue entries (favor later mutations)
    qs = sorted(qdir.iterdir())
    for p in qs[:80] + qs[-80:]:
        if p.is_file() and p.stat().st_size < 200_000:
            candidates.append(p)
# de-dupe by sha256
seen = set()
uniq = []
for p in candidates:
    h = hashlib.sha256(p.read_bytes()).hexdigest()
    if h in seen:
        continue
    seen.add(h)
    uniq.append(p)

def run(exe, path):
    try:
        r = subprocess.run([str(exe), ".", str(path)], capture_output=True, text=True, timeout=3)
        return (r.stdout or "") + (r.stderr or ""), r.returncode
    except Exception as e:
        return str(e), 99

beats_extra = 0
scanned = 0
for p in uniq:
    scanned += 1
    o0, _ = run(jq0, p)
    o1, _ = run(jq1, p)
    if o0 == o1:
        continue
    san_hit = False
    for exe in (asan, ubsan, msan):
        if not exe.exists():
            continue
        t, rc = run(exe, p)
        if rc not in (0, 1, 2, 3, 4, 5) and rc != 0:
            # jq parse errors are ok; sanitizer abort/signal is not
            pass
        if any(k in t.lower() for k in ("sanitizer", "runtime error", "summary:", "heap-", "stack-")):
            san_hit = True
        if rc < 0 or rc >= 128:  # signal
            san_hit = True
    if san_hit:
        continue
    # reproducibility x3
    stable = True
    for _ in range(3):
        r0, _ = run(jq0, p)
        r1, _ = run(jq1, p)
        if r0 != o0 or r1 != o1:
            stable = False
    if not stable:
        continue
    beats_extra += 1
    d = out / "confirmed" / f"scanbeat-{p.name.replace(',', '_')[:80]}"
    d.mkdir(parents=True, exist_ok=True)
    (d / "out0.txt").write_text(o0)
    (d / "out1.txt").write_text(o1)
    (d / "input").write_bytes(p.read_bytes())
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
