#!/usr/bin/env bash
# run-oracle-local.sh — Phase 1.1 portable differential oracle (no CompDiff required)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/work/oracle-local}"
echo "=== Phase 1.1: Differential Oracle Validation ==="
bash "$ROOT/targets/unstable-overflow/run-oracle.sh" "$OUT"
echo "ORACLE_LOCAL=PASS"
