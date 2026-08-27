#!/usr/bin/env bash
# CompDiff-compatible build.sh for libtiff tiffcp (sourced by diff-instrument.sh)
set -euo pipefail
SCRIPT="$1"
CAMP=$(dirname "$(realpath "$SCRIPT")")
SRC="${CDUB_ROOT:-/opt/cd-ub}/campaigns/beat-libtiff/src/libtiff"
WORKDIR="${CAMP}/cdub-src"
BINDIR="${CAMP}/cdub-bin"
mkdir -p "$WORKDIR" "$BINDIR"

if [[ -z "${DIFF_ID:-}" ]]; then
  BD="${WORKDIR}/libtiff-fuzz"
  cp -a "${SRC}/." "$BD/"
else
  BD="${WORKDIR}/libtiff-${DIFF_ID}"
  rm -rf "$BD"
  # Reuse configured tree from libtiff-0 to avoid autogen network fetch
  PREV="${WORKDIR}/libtiff-0"
  if [[ -d "$PREV" ]] && [[ -f "$PREV/configure" ]]; then
    cp -a "$PREV/." "$BD/"
  else
    cp -a "${SRC}/." "$BD/"
  fi
fi
cd "$BD"

export CC="${CC:?}"
export CXX="${CXX:?}"

if [[ ! -f configure ]]; then
  ./autogen.sh 2>&1 | tail -5 || true
fi
if [[ ! -f configure ]]; then
  echo "CONFIGURE_MISSING in $BD" >&2
  exit 1
fi
./configure --disable-shared --disable-docs \
  CC="$CC" CXX="$CXX" 2>&1 | tail -5
make -j"$(nproc)" clean 2>/dev/null || true
make -j"$(nproc)" all 2>&1 | tail -15

mkdir -p "$BINDIR"
if [[ -z "${DIFF_ID:-}" ]]; then
  ln -sfn "${BD}/tools/tiffcp" "${BINDIR}/tiffcp"
else
  ln -sfn "${BD}/tools/tiffcp" "${BINDIR}/tiffcp-${DIFF_ID}"
fi
