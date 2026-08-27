#!/usr/bin/env bash
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
OUT="${ROOT}/reports/live/beat-libtiff"
mkdir -p "$OUT"
pkill -f 'afl-fuzz.*beat-libtiff' 2>/dev/null || true
pkill -f 'beat-libtiff/hunt.sh' 2>/dev/null || true
sleep 1
: >"${OUT}/hunt-nohup.log"
nohup env HUNT_SECONDS="${HUNT_SECONDS:-1800}" \
  bash "${ROOT}/campaigns/beat-libtiff/hunt.sh" \
  >>"${OUT}/hunt-nohup.log" 2>&1 &
echo "PID=$!"
sleep 12
tail -40 "${OUT}/hunt-nohup.log" || true
ps -ef | grep -E 'afl-fuzz|beat-libtiff/hunt' | grep -v grep || true
