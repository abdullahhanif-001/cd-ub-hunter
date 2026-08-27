#!/usr/bin/env bash
# finish-beat-report.sh — write report + portfolio Campaign 2 link
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
python3 "${ROOT}/campaigns/beat-google/write-beat-report.py"
mkdir -p "${ROOT}/reports/portfolio" "${ROOT}/reports/beat-google"

link_campaign2() {
  local port="$1"
  if [ ! -f "$port" ]; then
    echo "# CD-UB Portfolio" >"$port"
  fi
  if ! grep -q "Campaign 2: Beat Google" "$port" 2>/dev/null; then
    {
      echo ""
      echo "## Campaign 2: Beat Google sanitizers on OSS-Fuzz target"
      echo "See [../beat-google/BEAT_REPORT.md](../beat-google/BEAT_REPORT.md)."
    } >>"$port"
  fi
}

link_campaign2 "${ROOT}/reports/portfolio/PORTFOLIO.md"
if [ -f "${ROOT}/reports/live/portfolio/PORTFOLIO.md" ]; then
  link_campaign2 "${ROOT}/reports/live/portfolio/PORTFOLIO.md"
fi

ls -la "${ROOT}/reports/beat-google/"
echo "---JSON---"
cat "${ROOT}/reports/beat-google/BEAT_REPORT.json"
echo "---PORTFOLIO---"
grep -A2 "Campaign 2" "${ROOT}/reports/portfolio/PORTFOLIO.md"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "FINISH_BEAT_OK"
