#!/usr/bin/env bash
# Contabo: background AFL hunt (2h default)
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
OUT="${ROOT}/reports/live/beat-google"
mkdir -p "$OUT"
pkill -f 'afl-fuzz' 2>/dev/null || true
pkill -f 'beat-google/hunt.sh' 2>/dev/null || true
sleep 1
: >"${OUT}/hunt-nohup.log"
nohup env HUNT_SECONDS="${HUNT_SECONDS:-7200}" \
  bash "${ROOT}/campaigns/beat-google/hunt.sh" \
  >>"${OUT}/hunt-nohup.log" 2>&1 &
echo "PID=$!"
sleep 12
wc -c "${OUT}/hunt-nohup.log" || true
tail -80 "${OUT}/hunt-nohup.log" || true
ps -ef | grep -E 'afl-fuzz|beat-google/hunt' | grep -v grep || true
