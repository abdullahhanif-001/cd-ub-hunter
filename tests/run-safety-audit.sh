#!/usr/bin/env bash
# run-safety-audit.sh — Phase 2 co-tenancy isolation & safety conformance
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CDUB_ROOT="${CDUB_ROOT:-$ROOT}"
echo "=== Phase 2: Co-tenancy Isolation & Safety Conformance ==="
bash "$ROOT/deploy/contabo/cyber-defensive-audit.sh"
