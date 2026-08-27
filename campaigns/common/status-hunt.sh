#!/usr/bin/env bash
# status-hunt.sh — one-shot AFL status for a beat campaign
set -euo pipefail

CAMPAIGN="${1:?campaign directory name under reports/live}"
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
OUT="${ROOT}/reports/live/${CAMPAIGN}"
STAT="${OUT}/findings/default/fuzzer_stats"

echo "UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [[ -f "$STAT" ]]; then
  grep -E '^(run_time|execs_done|execs_per_sec|paths_total|paths_found|unique_crashes|bitmap_cvg|cycles_done)' "$STAT"
fi

echo "DIFF_RAW=$(find "$OUT/findings" -path '*/diffs/*' -type f 2>/dev/null | wc -l | tr -d ' ')"
echo "DIFF_POST=$(find "$OUT/cdub_diffs" -type f 2>/dev/null | wc -l | tr -d ' ')"

if ! pgrep -af "afl-fuzz.*${CAMPAIGN}" | head -3; then
  echo "AFL_NOT_RUNNING"
fi

if ! bash "${ROOT}/deploy/contabo/pm2-guard.sh"; then
  echo "PM2_GUARD_WARN"
fi
