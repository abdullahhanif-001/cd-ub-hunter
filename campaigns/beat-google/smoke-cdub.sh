#!/usr/bin/env bash
set -euo pipefail
BIN0=/opt/cd-ub/campaigns/beat-google/cdub-bin/jq-0
BIN1=/opt/cd-ub/campaigns/beat-google/cdub-bin/jq-1
SEED=/opt/cd-ub/campaigns/beat-google/corpus/data.json
echo "=== jq-0 ==="
timeout 2 "$BIN0" . "$SEED" | head -5
echo "=== jq-1 ==="
timeout 2 "$BIN1" . "$SEED" | head -5
echo "=== fuzz bin ==="
timeout 2 /opt/cd-ub/campaigns/beat-google/cdub-bin/jq . "$SEED" | head -5
# strings for DIFF markers
strings /opt/cd-ub/campaigns/beat-google/cdub-src/jq-fuzz/jq | grep -iE 'diff|compdiff|cdub' | head || true
# fuzzer_stats diffs fields
grep -i diff /opt/cd-ub/reports/live/beat-google/findings/default/fuzzer_stats || true
grep -i diff /opt/cd-ub/reports/live/beat-google/findings/default/plot_data | tail -3 || true
