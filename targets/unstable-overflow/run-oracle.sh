#!/usr/bin/env bash
# Real dual-compile CD-UB oracle for unstable-overflow (gcc -O0 vs clang -O3)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$DIR/out}"
mkdir -p "$OUT"
SEED="${DIR}/seeds/overflow.txt"

gcc -O0 -o "$OUT/prog-gcc-O0" "$DIR/program.c"
clang -O3 -o "$OUT/prog-clang-O3" "$DIR/program.c"

"$OUT/prog-gcc-O0" "$SEED" >"$OUT/out-gcc-O0.txt" 2>&1 || true
"$OUT/prog-clang-O3" "$SEED" >"$OUT/out-clang-O3.txt" 2>&1 || true

echo "=== gcc -O0 ==="
cat "$OUT/out-gcc-O0.txt"
echo "=== clang -O3 ==="
cat "$OUT/out-clang-O3.txt"

if cmp -s "$OUT/out-gcc-O0.txt" "$OUT/out-clang-O3.txt"; then
  echo "CDUB_DEMO=NO_DIFF (unexpected on this seed — check compilers)"
  exit 1
fi

echo "CDUB_DEMO=DIFF_FOUND"
echo "CLASS=PROGRAM_UB"
echo "MOCK_PCT=0"
exit 0
