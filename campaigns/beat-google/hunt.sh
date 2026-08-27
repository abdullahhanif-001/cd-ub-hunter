#!/usr/bin/env bash
# hunt.sh — AFL -y 2 timed hunt + diff-post
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/config/ephemeral.env" 2>/dev/null || true
export AFL_NO_X86=1 AFL_NO_AFFINITY=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
bash "${ROOT}/deploy/contabo/pm2-guard.sh"

CAMP="${ROOT}/campaigns/beat-google"
OUT="${ROOT}/reports/live/beat-google"
FIND="${OUT}/findings"
SEEDS="${CAMP}/corpus"
# Plan: 2–4h; Contabo default 2h (override HUNT_SECONDS)
HUNT_SECONDS="${HUNT_SECONDS:-7200}"
N="$(jq '[.[].configs[]] | length' "${ROOT}/vendor/CompDiff/compilers/config")"
mkdir -p "$FIND" "$OUT/cdub_diffs"

# Ensure seeds nonempty
if [ ! "$(ls -A "$SEEDS" 2>/dev/null)" ]; then
  echo '{"a":1}' >"$SEEDS/fallback.json"
fi

BIN="${CAMP}/cdub-bin/jq"
test -x "$BIN"

# AFL fuzz jq '.' @@  (stdout)
timeout "$HUNT_SECONDS" \
  "${ROOT}/vendor/CompDiff/aflpp/afl-fuzz" -y "$N" \
  -i "$SEEDS" -o "$FIND" \
  -- "$BIN" "." @@ \
  2>&1 | tee "${OUT}/hunt.log" | tail -50 || true

DIFF_DIR="${FIND}/default/diffs"
if [ ! -d "$DIFF_DIR" ]; then
  # AFL++ layout may be findings/diffs
  DIFF_DIR="${FIND}/diffs"
fi
mkdir -p "$DIFF_DIR"

# Post-filter
if [ -n "$(ls -A "$DIFF_DIR" 2>/dev/null || true)" ]; then
  python3 "${ROOT}/vendor/CompDiff/diff-post.py" \
    --bin "$BIN" --args ". @@" -y "$N" -r 1 \
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
