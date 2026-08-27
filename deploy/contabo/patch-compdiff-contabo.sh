#!/usr/bin/env bash
# Patch CompDiff for Contabo: clang-18 incompatible flags + use gcc-plugin AFL
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
DI="$ROOT/vendor/CompDiff/diff-instrument.sh"
if [ -f "$DI" ]; then
  sed -i 's|afl-clang-fast++|afl-g++-fast|g; s|afl-clang-fast|afl-gcc-fast|g' "$DI"
  echo "PATCHED diff-instrument -> afl-gcc-fast"
fi
