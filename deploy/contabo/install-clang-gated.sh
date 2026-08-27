#!/usr/bin/env bash
# install-clang-gated.sh — apt install clang only; pm2-guard before/after; never llvm.sh
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
GUARD="${ROOT}/deploy/contabo/pm2-guard.sh"

if [ -x "$GUARD" ]; then
  bash "$GUARD"
fi

if command -v clang >/dev/null 2>&1 && command -v clang++ >/dev/null 2>&1; then
  echo "CLANG_ALREADY_PRESENT $(clang --version | head -1)"
  bash "$GUARD" 2>/dev/null || true
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends clang

command -v clang >/dev/null
command -v clang++ >/dev/null
echo "CLANG_INSTALLED $(clang --version | head -1)"

if [ -x "$GUARD" ]; then
  bash "$GUARD"
fi
echo "CLANG_GATE=PASS"
