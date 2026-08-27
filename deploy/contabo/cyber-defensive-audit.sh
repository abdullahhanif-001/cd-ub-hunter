#!/usr/bin/env bash
# cyber-defensive-audit.sh — T2: prove wrappers cannot harm co-resident services
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
cd "$ROOT"
FAIL=0

echo "=== T2 cyber defensive ==="

# 1) No pm2 mutate in our wrappers
if grep -RInE 'pm2 (restart|reload|stop|start|delete|kill)' deploy scripts config 2>/dev/null; then
  echo "FAIL: pm2 mutate present"
  FAIL=1
else
  echo "PASS: no pm2 mutate in wrappers"
fi

# 2) No nginx reload
if grep -RInE 'nginx|systemctl (reload|restart) nginx' deploy scripts config 2>/dev/null | grep -v ROLLBACK | grep -v 'never' | grep -v Forbidden; then
  # allow mentions in comments/docs saying never touch
  :
fi
if grep -RInE 'systemctl (reload|restart) nginx|docker (stop|rm).*mongo' deploy scripts 2>/dev/null; then
  echo "FAIL: nginx/mongo mutate commands"
  FAIL=1
else
  echo "PASS: no nginx/mongo mutate commands"
fi

# 3) Jail: install scripts only mention /opt/cd-ub*
if grep -RInE 'rsync.*/opt/(elite|xerosphere|rider)' deploy scripts 2>/dev/null; then
  echo "FAIL: path escape to other /opt apps"
  FAIL=1
else
  echo "PASS: no /opt escape to other apps"
fi

# 4) Secrets not in tree
if find . -name '*.pem' -o -name 'id_rsa*' -o -name '*.env.local' 2>/dev/null | grep -v vendor | head -5 | grep .; then
  echo "FAIL: secret-like files present"
  FAIL=1
else
  echo "PASS: no obvious secrets"
fi

# 5) Caps visible
if systemctl show cd-ub.service -p CPUQuota -p MemoryMax 2>/dev/null | grep -E 'CPUQuota|MemoryMax'; then
  echo "PASS: systemd caps visible"
else
  echo "WARN: cd-ub.service caps not visible (unit may be oneshot true)"
fi

# 6) Wipe blocked without confirm
WIPE_OUT="$(CONFIRM_USER_WIPE=0 AUTO_WIPE=0 bash deploy/contabo/wipe-ephemeral.sh 2>&1 || true)"
if echo "$WIPE_OUT" | grep -q REFUSED; then
  echo "PASS: wipe refused without confirm"
else
  echo "FAIL: wipe did not refuse"
  echo "$WIPE_OUT"
  FAIL=1
fi

# 7) pm2-guard
bash deploy/contabo/pm2-guard.sh || FAIL=1

if [ "$FAIL" -ne 0 ]; then
  echo "T2_CYBER=FAIL"
  exit 1
fi
echo "T2_CYBER=PASS"
exit 0
