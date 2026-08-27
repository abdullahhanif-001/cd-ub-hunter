#!/usr/bin/env bash
set -euo pipefail
export AFL_NO_X86=1 AFL_NO_AFFINITY=1
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends gcc-13-plugin-dev 2>&1 | tail -5
cd /opt/cd-ub/vendor/CompDiff/aflpp
make clean >/dev/null 2>&1 || true
# C++17 required for LLVM 18 headers with this old AFL++
export CXXFLAGS="-std=c++17"
CC=clang CXX=clang++ make source-only 2>&1 | tee /opt/cd-ub/reports/live/afl-rebuild.log | tail -60
ls -la afl-fuzz afl-clang-fast afl-clang-fast++ 2>&1
test -x ./afl-fuzz
test -x ./afl-clang-fast
echo AFL_BUILD_OK
