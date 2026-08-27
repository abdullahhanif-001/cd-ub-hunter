#!/usr/bin/env bash
# hunt.sh — AFL timed hunt + diff-post (parameterized campaign)
set -euo pipefail

CAMPAIGN="${1:?campaign name e.g. beat-google}"
BIN_REL="${2:?path to instrumented binary relative to campaign dir}"
AFL_ARGS=("${@:3}")

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/campaigns/common/campaign-env.sh"
# shellcheck disable=SC1091
source "${ROOT}/campaigns/common/dir-utils.sh"
export AFL_NO_X86=1 AFL_NO_AFFINITY=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
bash "${ROOT}/deploy/contabo/pm2-guard.sh"

CAMP="${ROOT}/campaigns/${CAMPAIGN}"
OUT="${ROOT}/reports/live/${CAMPAIGN}"
FIND="${OUT}/findings"
SEEDS="${CAMP}/corpus"
HUNT_SECONDS="${HUNT_SECONDS:-7200}"
N="$(jq '[.[].configs[]] | length' "${ROOT}/vendor/CompDiff/compilers/config")"
mkdir -p "$FIND" "$OUT/cdub_diffs"

if ! dir_has_entries "$SEEDS"; then
  echo '{"a":1}' >"$SEEDS/fallback.json"
fi

BIN="${CAMP}/${BIN_REL}"
test -x "$BIN"

set +e
timeout "$HUNT_SECONDS" \
  "${ROOT}/vendor/CompDiff/aflpp/afl-fuzz" -y "$N" \
  -i "$SEEDS" -o "$FIND" \
  -- "$BIN" "${AFL_ARGS[@]}" \
  2>&1 | tee "${OUT}/hunt.log" | tail -50
set -e

DIFF_DIR="${FIND}/default/diffs"
if [ ! -d "$DIFF_DIR" ]; then
  DIFF_DIR="${FIND}/diffs"
fi
mkdir -p "$DIFF_DIR"

if dir_has_entries "$DIFF_DIR"; then
  POST_ARGS="${DIFF_POST_ARGS:-${AFL_ARGS[*]}}"
  if python3 "${ROOT}/vendor/CompDiff/diff-post.py" \
    --bin "$BIN" --args "$POST_ARGS" -y "$N" -r 1 \
    -i "$DIFF_DIR" -o "${OUT}/cdub_post" \
    2>&1 | tee "${OUT}/diff-post.log"; then
    if [ -d "${OUT}/cdub_post/diffs" ]; then
      cp -a "${OUT}/cdub_post/diffs/." "${OUT}/cdub_diffs/"
    fi
  else
    echo "WARN: diff-post returned non-zero" >&2
  fi
else
  echo "NO_RAW_DIFFS" | tee "${OUT}/hunt_status.txt"
fi

echo "DIFF_COUNT=$(count_files_under "${OUT}/cdub_diffs")" | tee -a "${OUT}/hunt_status.txt"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "HUNT_DONE"
