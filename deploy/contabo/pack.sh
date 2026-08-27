#!/usr/bin/env bash
# pack.sh — create one cd-ub-<sha>.tar.gz for scp deploy
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

PIN="$(cat VENDOR_PIN.txt | awk '/Pinned commit:/{print $3}')"
SHA="${PIN:0:12}"
OUT="cd-ub-${SHA}.tar.gz"

# Grep gate: forbid PM2 mutate in our wrappers (not vendor AFL source noise)
BAD="$(grep -RInE 'pm2 (restart|reload|stop|start|delete|kill)' deploy scripts config 2>/dev/null || true)"
if [ -n "$BAD" ]; then
  echo "FAIL: pm2 mutate commands found in wrappers:"
  echo "$BAD"
  exit 1
fi

# Grep gate: wipe must require confirm
if ! grep -q 'CONFIRM_USER_WIPE' deploy/contabo/wipe-ephemeral.sh; then
  echo "FAIL: wipe script missing CONFIRM_USER_WIPE gate"
  exit 1
fi

# Ensure vendored CompDiff for tarball (git repo excludes vendor/)
if [ ! -d vendor/CompDiff/aflpp ]; then
  echo "Fetching CompDiff for pack..."
  mkdir -p vendor
  rm -rf vendor/CompDiff
  git clone --depth 1 https://github.com/shao-hua-li/CompDiff.git vendor/CompDiff
  git -C vendor/CompDiff checkout "${PIN}" 2>/dev/null || true
fi

rm -f "$OUT"
tar --exclude='.git' \
  --exclude='vendor/CompDiff/.git' \
  --exclude='*.tar.gz' \
  --exclude='reports/live/*' \
  -czf "$OUT" \
  VENDOR_PIN.txt \
  README.md \
  .gitignore \
  config \
  profiles \
  templates \
  deploy \
  scripts \
  targets \
  campaigns \
  vendor/CompDiff \
  reports/.gitkeep

ls -lh "$OUT"
echo "PACK_OK $OUT"
echo "$OUT" >.last-pack-name
