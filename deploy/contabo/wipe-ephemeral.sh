#!/usr/bin/env bash
# wipe-ephemeral.sh — DISABLED by default. Requires user chat order + CONFIRM_USER_WIPE=1.
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
INCOMING="${CDUB_INCOMING:-/opt/cd-ub-incoming}"

if [[ -f "${ROOT}/config/ephemeral.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/config/ephemeral.env"
fi

AUTO_WIPE="${AUTO_WIPE:-0}"
CONFIRM_USER_WIPE="${CONFIRM_USER_WIPE:-0}"
WIPE_REASON="${WIPE_REASON:-}"

if [[ "$AUTO_WIPE" != "1" ]] && [[ "$CONFIRM_USER_WIPE" != "1" ]]; then
  echo "REFUSED: wipe blocked (AUTO_WIPE=$AUTO_WIPE CONFIRM_USER_WIPE=$CONFIRM_USER_WIPE)"
  echo "Only run after explicit user order: CONFIRM_USER_WIPE=1 WIPE_REASON='...' $0"
  exit 1
fi
if [[ "$CONFIRM_USER_WIPE" != "1" ]]; then
  echo "REFUSED: CONFIRM_USER_WIPE must be 1"
  exit 1
fi
if [[ -z "$WIPE_REASON" ]]; then
  echo "REFUSED: WIPE_REASON required (document user chat order)"
  exit 1
fi

GUARD="${ROOT}/deploy/contabo/pm2-guard.sh"
if [[ -x "$GUARD" ]]; then
  bash "$GUARD" || { echo "FAIL: pm2-guard before wipe"; exit 1; }
fi

echo "Wiping CD-UB only. Reason: $WIPE_REASON"
systemctl stop cd-ub.service 2>/dev/null || true
systemctl disable cd-ub.service 2>/dev/null || true
rm -f /etc/systemd/system/cd-ub.service
systemctl daemon-reload 2>/dev/null || true

rm -rf "$ROOT" "$INCOMING"

if [[ -e "$ROOT" ]] || [[ -e "$INCOMING" ]]; then
  echo "FAIL: residue remains"
  exit 1
fi

# re-check PM2 using a minimal inline guard (root gone)
if command -v pm2 >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  ONLINE="$(pm2 jlist | jq '[.[].pm2_env.status]] | all(. == "online")')"
  [[ "$ONLINE" = "true" ]] || { echo "FAIL: PM2 not all online after wipe"; exit 1; }
fi

echo "VPS_WIPE=PASS"
exit 0
