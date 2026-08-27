# Rollback CD-UB on VPS

## Rules
- Never touch PM2 apps, nginx, or `rider-tracker-mongo`.
- Stop/disable only `cd-ub.service`.
- Prefer `previous/` extract under `/opt/cd-ub` if present.

## Quick rollback (keep tree, stop work)
```bash
systemctl stop cd-ub.service || true
systemctl disable cd-ub.service || true
bash /opt/cd-ub/deploy/contabo/pm2-guard.sh
```

## Restore previous extract
```bash
systemctl stop cd-ub.service || true
if [ -d /opt/cd-ub/previous ]; then
  # previous holds last good tree snapshot metadata; re-extract from saved tar if needed
  echo "Use saved tar in /opt/cd-ub-incoming or re-scp pack"
fi
bash /opt/cd-ub/deploy/contabo/pm2-guard.sh
```

## Full wipe (ONLY when user explicitly orders)
```bash
CONFIRM_USER_WIPE=1 WIPE_REASON='user ordered wipe' bash /opt/cd-ub/deploy/contabo/wipe-ephemeral.sh
```
