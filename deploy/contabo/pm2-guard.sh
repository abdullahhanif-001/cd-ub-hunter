#!/usr/bin/env bash
# pm2-guard.sh — shared VPS PM2 x6 safety (delta restarts, never mutate PM2)
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
BASELINE="${ROOT}/baseline/pm2-before.json"
ENV_FILE="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)/config/ephemeral.env"
if [[ -f "${ROOT}/config/ephemeral.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/config/ephemeral.env"
elif [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1091
  source "$ENV_FILE"
fi

if ! command -v pm2 >/dev/null 2>&1; then
  echo "FAIL: pm2 not found"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq required for pm2-guard"
  exit 1
fi

CURRENT="$(mktemp)"
pm2 jlist >"$CURRENT"

COUNT="$(jq 'length' "$CURRENT")"
if [[ "$COUNT" -lt 6 ]]; then
  echo "FAIL: expected >=6 PM2 apps, got $COUNT"
  rm -f "$CURRENT"
  exit 1
fi

ONLINE="$(jq '[.[].pm2_env.status]] | all(. == "online")' "$CURRENT")"
if [[ "$ONLINE" != "true" ]]; then
  echo "FAIL: not all PM2 apps online"
  jq -r '.[]] | select(.pm2_env.status != "online") | .name + " " + .pm2_env.status' "$CURRENT" || true
  rm -f "$CURRENT"
  exit 1
fi

if [[ ! -f "$BASELINE" ]]; then
  echo "WARN: no baseline at $BASELINE — snapshot-only mode OK for first run"
  echo "PM2_GUARD_OK count=$COUNT (no baseline yet)"
  rm -f "$CURRENT"
  exit 0
fi

CUR_SUM="$(jq '[.[].pm2_env.restart_time]] | add // 0' "$CURRENT")"
BASE_SUM="$(jq '[.[].pm2_env.restart_time]] | add // 0' "$BASELINE")"

if [[ "$CUR_SUM" -gt "$BASE_SUM" ]]; then
  echo "FAIL: PM2 restart sum increased ($BASE_SUM -> $CUR_SUM)"
  rm -f "$CURRENT"
  # stop only cd-ub if present — never PM2
  systemctl stop cd-ub.service 2>/dev/null || true
  exit 1
fi

echo "PM2_GUARD_OK count=$COUNT restarts_sum=$CUR_SUM baseline_sum=$BASE_SUM"
rm -f "$CURRENT"
exit 0
