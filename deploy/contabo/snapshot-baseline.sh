#!/usr/bin/env bash
# snapshot-baseline.sh — write PM2/disk/mem baseline under /opt/cd-ub/baseline
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
mkdir -p "${ROOT}/baseline"
pm2 jlist >"${ROOT}/baseline/pm2-before.json"
pm2 list >"${ROOT}/baseline/pm2-before.txt" || true
free -m >"${ROOT}/baseline/mem-before.txt"
df -h / >"${ROOT}/baseline/df-before.txt"
ss -tlnp >"${ROOT}/baseline/ports-before.txt" || true
date -u >"${ROOT}/baseline/taken-at.txt"
echo "BASELINE_OK ${ROOT}/baseline"
