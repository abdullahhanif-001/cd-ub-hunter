#!/usr/bin/env bash
# triage-finding.sh — classify a CompDiff diff into report template
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
CLASS="${1:-PROGRAM_UB}"
TARGET="${2:-unknown}"
INPUT="${3:-}"
OUTDIR="${ROOT}/reports/live/triage-$(date +%Y%m%d%H%M%S)"
mkdir -p "$OUTDIR"

cp "${ROOT}/templates/triage-report.md" "$OUTDIR/report.md"
{
  echo "CLASS=$CLASS"
  echo "TARGET=$TARGET"
  echo "INPUT=$INPUT"
  echo "CONFIGS=${CDUB_PROFILE:-speed-2}"
  echo "MOCK_PCT=0"
  echo "NOTES=automated-triage stub; human refine as needed"
} >"$OUTDIR/meta.env"

# Known unsupported: nondeterministic markers
case "$CLASS" in
  PROGRAM_UB|COMPILER_BUG|FP_MODE|LINE_MACRO|NOISE|UNSUPPORTED_NONDET) ;;
  *) echo "WARN: unusual class $CLASS" ;;
esac

echo "TRIAGE_OK $OUTDIR CLASS=$CLASS"
