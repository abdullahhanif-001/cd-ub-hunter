#!/usr/bin/env bash
# hunt.sh — AFL -y 2 -Y out.file timed hunt + diff-post (30 min default)
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/config/ephemeral.env" 2>/dev/null || true
export AFL_NO_X86=1 AFL_NO_AFFINITY=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
bash "${ROOT}/deploy/contabo/pm2-guard.sh"

CAMP="${ROOT}/campaigns/beat-libtiff"
OUT="${ROOT}/reports/live/beat-libtiff"
FIND="${OUT}/findings"
SEEDS="${CAMP}/corpus"
HUNT_SECONDS="${HUNT_SECONDS:-1800}"
OUT_FILE="out.file"
N="$(jq '[.[].configs[]] | length' "${ROOT}/vendor/CompDiff/compilers/config")"
mkdir -p "$FIND" "$OUT/cdub_diffs"

if [ ! "$(ls -A "$SEEDS" 2>/dev/null)" ]; then
  printf 'II*\x00\x08\x00\x00\x00' >"$SEEDS/fallback.tif"
fi

BIN="${CAMP}/cdub-bin/tiffcp"
test -x "$BIN"

# Pre-scan fast path
bash "${CAMP}/pre-hunt-scan.sh" || true

timeout "$HUNT_SECONDS" \
  "${ROOT}/vendor/CompDiff/aflpp/afl-fuzz" -y "$N" -Y "$OUT_FILE" \
  -i "$SEEDS" -o "$FIND" \
  -- "$BIN" -M -i @@ "$OUT_FILE" \
  2>&1 | tee "${OUT}/hunt.log" | tail -50 || true

DIFF_DIR="${FIND}/default/diffs"
[ -d "$DIFF_DIR" ] || DIFF_DIR="${FIND}/diffs"
mkdir -p "$DIFF_DIR"

if [ -n "$(ls -A "$DIFF_DIR" 2>/dev/null || true)" ]; then
  python3 "${ROOT}/vendor/CompDiff/diff-post.py" \
    --bin "$BIN" --args "-M -i @@" --out_file "$OUT_FILE" -y "$N" -r 1 \
    -i "$DIFF_DIR" -o "${OUT}/cdub_post" \
    2>&1 | tee "${OUT}/diff-post.log" || true
  if [ -d "${OUT}/cdub_post/diffs" ]; then
    cp -a "${OUT}/cdub_post/diffs/." "${OUT}/cdub_diffs/" || true
  fi
else
  echo "NO_RAW_DIFFS" | tee "${OUT}/hunt_status.txt"
fi

echo "DIFF_COUNT=$(find "${OUT}/cdub_diffs" -type f 2>/dev/null | wc -l)" | tee -a "${OUT}/hunt_status.txt"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "HUNT_DONE"
