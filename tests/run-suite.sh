#!/usr/bin/env bash
# run-suite.sh — full Phase 1–3 verification on deployed CD-UB host
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CDUB_ROOT="${CDUB_ROOT:-/opt/cd-ub}"
if [[ -d "$ROOT/deploy/contabo" ]] && [[ -f "$ROOT/config/ephemeral.env" ]]; then
  export CDUB_ROOT="$ROOT"
fi

echo "=== CD-UB Hunter Verification Suite ==="
echo "ROOT=$CDUB_ROOT"
echo "DATE_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ -x "$CDUB_ROOT/vendor/CompDiff/aflpp/afl-fuzz" ]]; then
  bash "$CDUB_ROOT/deploy/contabo/finish-tests.sh"
else
  echo "WARN: CompDiff not built — running portable phases only"
  bash "$ROOT/tests/run-oracle-local.sh"
  bash "$ROOT/tests/run-safety-audit.sh"
fi

echo "SUITE_COMPLETE"
