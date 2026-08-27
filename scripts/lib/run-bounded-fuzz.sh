#!/usr/bin/env bash
# run-bounded-fuzz.sh — bounded AFL++ session with explicit non-zero tolerance
set -euo pipefail

TIMEOUT_SEC="${1:?timeout seconds}"
shift
FUZZ_CMD=("$@")

set +e
timeout "$TIMEOUT_SEC" "${FUZZ_CMD[@]}"
FUZZ_RC=$?
set -e

case "$FUZZ_RC" in
  0|124|130) echo "FUZZ_SESSION=ENDED rc=$FUZZ_RC" ;;
  *) echo "WARN: fuzz exited rc=$FUZZ_RC" >&2 ;;
esac
