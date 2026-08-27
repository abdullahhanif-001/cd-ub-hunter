#!/usr/bin/env bash
# run-all.sh — full Beat Google libtiff campaign
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
export CDUB_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/campaigns/common/campaign-env.sh"
export AFL_NO_X86=1 AFL_NO_AFFINITY=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export HUNT_SECONDS="${HUNT_SECONDS:-1800}"

CAMP="${ROOT}/campaigns/beat-libtiff"
OUT="${ROOT}/reports/live/beat-libtiff"
mkdir -p "$OUT" "${ROOT}/reports/beat-libtiff"
cp -f "${CAMP}/CLAIM.md" "${OUT}/CLAIM.md" 2>/dev/null || true

bash "${ROOT}/deploy/contabo/pm2-guard.sh"
bash "${CAMP}/select-libtiff.sh"
bash "${CAMP}/build-sanitizer-baseline.sh"
bash "${CAMP}/build-cdub-libtiff.sh"
bash "${CAMP}/hunt.sh"
bash "${CAMP}/confirm-beat.sh"
bash "${CAMP}/finish-beat-report.sh"

bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "RUN_ALL_DONE"
cat "${ROOT}/reports/beat-libtiff/BEAT_REPORT.json" | head -45
