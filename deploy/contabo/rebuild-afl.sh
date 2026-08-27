#!/usr/bin/env bash
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
export AFL_NO_X86=1 AFL_NO_AFFINITY=1
export DEBIAN_FRONTEND=noninteractive

apt-get install -y --no-install-recommends gcc-13-plugin-dev 2>&1 | tail -5

AF_DIR="${ROOT}/vendor/CompDiff/aflpp"
if [[ ! -d "$AF_DIR" ]]; then
  echo "FATAL: AFL++ tree missing at $AF_DIR" >&2
  exit 1
fi

cd "$AF_DIR"
if ! make clean >/dev/null 2>&1; then
  echo "WARN: make clean returned non-zero (continuing)" >&2
fi

export CXXFLAGS="-std=c++17"
CC=clang CXX=clang++ make source-only 2>&1 | tee "${ROOT}/reports/live/afl-rebuild.log" | tail -60
ls -la afl-fuzz afl-clang-fast afl-clang-fast++ 2>&1
[[ -x ./afl-fuzz ]]
[[ -x ./afl-clang-fast ]]
echo "AFL_BUILD_OK"
