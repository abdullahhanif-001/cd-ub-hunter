#!/usr/bin/env bash
# CompDiff-compatible build.sh for jq (sourced by diff-instrument.sh)
# Expects CC/CXX/DIFF_ID from CompDiff.
set -euo pipefail
SCRIPT="$1"
BASEDIR=$(dirname "$(realpath "$SCRIPT")")
# campaigns/beat-google/jq-build.sh lives next to instrument paths
CAMP=$(dirname "$(realpath "$SCRIPT")")
JQ_SRC="${CDUB_ROOT:-/opt/cd-ub}/campaigns/beat-google/src/jq"
WORKDIR="${CAMP}/cdub-src"
BINDIR="${CAMP}/cdub-bin"
mkdir -p "$WORKDIR" "$BINDIR"

if [ -z "${DIFF_ID:-}" ]; then
  BD="${WORKDIR}/jq-fuzz"
else
  BD="${WORKDIR}/jq-${DIFF_ID}"
fi
rm -rf "$BD"
mkdir -p "$BD"
cp -a "${JQ_SRC}/." "$BD/"
cd "$BD"
# Ensure configure
if [ ! -x configure ]; then
  autoreconf -fi 2>/dev/null || autoreconf -i || true
fi
export CC="${CC:?}"
export CXX="${CXX:?}"
./configure --disable-shared --disable-docs --with-oniguruma=builtin \
  CC="$CC" CXX="$CXX" 2>&1 | tail -5
make -j"$(nproc)" 2>&1 | tail -10
mkdir -p "$BINDIR"
if [ -z "${DIFF_ID:-}" ]; then
  ln -sfn "${BD}/jq" "${BINDIR}/jq"
else
  ln -sfn "${BD}/jq" "${BINDIR}/jq-${DIFF_ID}"
fi
