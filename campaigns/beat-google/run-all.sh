#!/usr/bin/env bash
# run-all.sh — full Beat Google campaign (pm2-guard wrapped)
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
export CDUB_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/campaigns/common/campaign-env.sh"
export AFL_NO_X86=1 AFL_NO_AFFINITY=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
# Plan 2–4h; default 2h
export HUNT_SECONDS="${HUNT_SECONDS:-7200}"

CAMP="${ROOT}/campaigns/beat-google"
OUT="${ROOT}/reports/live/beat-google"
mkdir -p "$OUT" "${ROOT}/reports/beat-google"
cp -f "${CAMP}/CLAIM.md" "${OUT}/CLAIM.md" 2>/dev/null || true

bash "${ROOT}/deploy/contabo/pm2-guard.sh"
bash "${CAMP}/select-jq.sh"
bash "${CAMP}/build-sanitizer-baseline.sh"
bash "${CAMP}/build-cdub-jq.sh"
bash "${CAMP}/hunt.sh"
bash "${CAMP}/confirm-beat.sh"
python3 "${CAMP}/write-beat-report.py"

# Link from portfolio
PORT="${ROOT}/reports/portfolio/PORTFOLIO.md"
if [[ -f "$PORT" ]]; then
  if ! grep -q "Campaign 2: Beat Google" "$PORT" 2>/dev/null; then
    {
      echo ""
      echo "## Campaign 2: Beat Google sanitizers on OSS-Fuzz target"
      echo "See [[../beat-google/BEAT_REPORT.md](../beat-google/BEAT_REPORT.md)."
    } >>"$PORT"
  fi
fi
# also local live copy
mkdir -p "${ROOT}/reports/portfolio"
if [[ -f "${ROOT}/reports/live/portfolio/PORTFOLIO.md" ]]; then
  if ! grep -q "Campaign 2: Beat Google" "${ROOT}/reports/live/portfolio/PORTFOLIO.md" 2>/dev/null; then
    {
      echo ""
      echo "## Campaign 2: Beat Google sanitizers on OSS-Fuzz target"
      echo "See [[../beat-google/BEAT_REPORT.md](../beat-google/BEAT_REPORT.md)."
    } >>"${ROOT}/reports/live/portfolio/PORTFOLIO.md"
  fi
fi

bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "RUN_ALL_DONE"
cat "${OUT}/BEAT_REPORT.json" | head -40
