#!/usr/bin/env bash
# Phase 2: co-tenancy isolation and safety conformance audit
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
cd "$ROOT"
FAIL=0

echo "=== Phase 2: Co-tenancy Isolation & Safety Conformance ==="

# 2.1 — Wrapper must not mutate co-resident PM2 processes
if grep -RInE 'pm2 (restart|reload|stop|start|delete|kill)' deploy scripts config 2>/dev/null; then
  echo "FAIL [2.1]: PM2 mutation commands present in wrapper tree"
  FAIL=1
else
  echo "PASS [2.1]: No PM2 mutation commands in wrappers"
fi

# 2.2 — No nginx/mongo service disruption
if grep -RInE 'nginx|systemctl (reload|restart) nginx' deploy scripts config 2>/dev/null | grep -v ROLLBACK | grep -v 'never' | grep -v Forbidden; then
  :
fi
if grep -RInE 'systemctl (reload|restart) nginx|docker (stop|rm).*mongo' deploy scripts 2>/dev/null; then
  echo "FAIL [2.2]: nginx/mongo disruption commands detected"
  FAIL=1
else
  echo "PASS [2.2]: No nginx/mongo disruption commands"
fi

# 2.3 — Path confinement under /opt/cd-ub
if grep -RInE 'rsync.*/opt/(elite|xerosphere|rider)' deploy scripts 2>/dev/null; then
  echo "FAIL [2.3]: Path escape to co-resident /opt applications"
  FAIL=1
else
  echo "PASS [2.3]: No path escape to co-resident applications"
fi

# 2.4 — Secret surface scan
if find . -name '*.pem' -o -name 'id_rsa*' -o -name '*.env.local' 2>/dev/null | grep -v vendor | head -5 | grep .; then
  echo "FAIL [2.4]: Secret-like artifacts present in owned tree"
  FAIL=1
else
  echo "PASS [2.4]: No secret-like artifacts in owned tree"
fi

# 2.5 — systemd resource envelope
if systemctl show cd-ub.service -p CPUQuota -p MemoryMax 2>/dev/null | grep -E 'CPUQuota|MemoryMax'; then
  echo "PASS [2.5]: systemd resource caps visible"
else
  echo "WARN [2.5]: cd-ub.service caps not visible (unit may be oneshot)"
fi

# 2.6 — Destructive wipe requires explicit operator confirmation
WIPE_OUT="$(CONFIRM_USER_WIPE=0 AUTO_WIPE=0 bash deploy/contabo/wipe-ephemeral.sh 2>&1 || true)"
if echo "$WIPE_OUT" | grep -q REFUSED; then
  echo "PASS [2.6]: Ephemeral wipe gated behind explicit confirmation"
else
  echo "FAIL [2.6]: Wipe executed or failed to refuse without confirmation"
  echo "$WIPE_OUT"
  FAIL=1
fi

# 2.7 — PM2 co-tenancy guard
bash deploy/contabo/pm2-guard.sh || FAIL=1

if [ "$FAIL" -ne 0 ]; then
  echo "PHASE2_RESULT=FAIL"
  exit 1
fi
echo "PHASE2_RESULT=PASS"
exit 0
