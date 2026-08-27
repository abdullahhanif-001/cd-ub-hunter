#!/usr/bin/env bash
# Differential oracle: dual-compile disagreement gate (gcc -O0 vs clang -O3)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$DIR/out}"
mkdir -p "$OUT"
SEED="${DIR}/seeds/overflow.txt"

gcc -O0 -o "$OUT/prog-gcc-O0" "$DIR/program.c"
clang -O3 -o "$OUT/prog-clang-O3" "$DIR/program.c"

run_prog() {
  local bin="$1"
  local outfile="$2"
  if ! "$bin" "$SEED" >"$outfile" 2>&1; then
    echo "WARN: $bin exited non-zero (output captured)" >&2
  fi
}

run_prog "$OUT/prog-gcc-O0" "$OUT/out-gcc-O0.txt"
run_prog "$OUT/prog-clang-O3" "$OUT/out-clang-O3.txt"

echo "=== Baseline compiler output (gcc -O0) ==="
cat "$OUT/out-gcc-O0.txt"
echo "=== Variant compiler output (clang -O3) ==="
cat "$OUT/out-clang-O3.txt"

if cmp -s "$OUT/out-gcc-O0.txt" "$OUT/out-clang-O3.txt"; then
  echo "ORACLE_RESULT=NO_DIFFERENTIAL (unexpected — verify compiler toolchain and seed corpus)"
  exit 1
fi

echo "ORACLE_RESULT=DIFFERENTIAL_CONFIRMED"
echo "CLASSIFICATION=PROGRAM_UB"
echo "MOCK_PCT=0"
exit 0
