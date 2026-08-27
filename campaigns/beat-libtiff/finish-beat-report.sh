#!/usr/bin/env bash
# finish-beat-report.sh — write report + portfolio Campaign 3 link
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
python3 "${ROOT}/campaigns/beat-libtiff/write-beat-report.py"
mkdir -p "${ROOT}/reports/portfolio" "${ROOT}/reports/beat-libtiff"

link_campaign3() {
  local port="$1"
  if [[ ! -f "$port" ]]; then
    echo "# CD-UB Portfolio" >"$port"
  fi
  if ! grep -q "Campaign 3: Beat Google on libtiff" "$port" 2>/dev/null; then
    {
      echo ""
      echo "## Campaign 3: Beat Google on libtiff"
      echo "See [[../beat-libtiff/BEAT_REPORT.md](../beat-libtiff/BEAT_REPORT.md)."
    } >>"$port"
  fi
}

link_campaign3 "${ROOT}/reports/portfolio/PORTFOLIO.md"
if [[ -f "${ROOT}/reports/live/portfolio/PORTFOLIO.md" ]]; then
  link_campaign3 "${ROOT}/reports/live/portfolio/PORTFOLIO.md"
fi

ls -la "${ROOT}/reports/beat-libtiff/"
echo "---JSON---"
cat "${ROOT}/reports/beat-libtiff/BEAT_REPORT.json"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "FINISH_BEAT_OK"
