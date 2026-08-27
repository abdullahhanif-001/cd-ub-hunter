#!/usr/bin/env bash
set -euo pipefail
OUT=/opt/cd-ub/reports/live/beat-libtiff
STAT="$OUT/findings/default/fuzzer_stats"
echo "UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [ -f "$STAT" ]; then
  grep -E '^(run_time|execs_done|execs_per_sec|paths_total|paths_found|unique_crashes|bitmap_cvg|cycles_done)' "$STAT"
fi
echo "DIFF_RAW=$(find "$OUT/findings" -path '*/diffs/*' -type f 2>/dev/null | wc -l)"
echo "DIFF_POST=$(find "$OUT/cdub_diffs" -type f 2>/dev/null | wc -l)"
cat "$OUT/pre_scan_summary.txt" 2>/dev/null || true
pgrep -af 'afl-fuzz.*beat-libtiff' | head -3 || echo AFL_NOT_RUNNING
bash /opt/cd-ub/deploy/contabo/pm2-guard.sh || true
