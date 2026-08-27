#!/usr/bin/env bash
# CompDiff-compatible build.sh for unstable-overflow (instrument path)
set -euo pipefail

SCRIPT_PATH="$(realpath "$1")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
BASEDIR="${SCRIPT_DIR}/src/unstable"
BINDIR="${SCRIPT_DIR}/bin"

if [[ -z "${DIFF_ID:-}" ]]; then
  BASEDIR="${BASEDIR}-fuzz"
else
  BASEDIR="${BASEDIR}-${DIFF_ID}"
fi

rm -rf "${BASEDIR}"
mkdir -p "${BASEDIR}" "${BINDIR}"
cp "${SCRIPT_DIR}/program.c" "${BASEDIR}/program.c"
cdub_safe_cd() { cd "$1" || exit 1; }
cdub_safe_cd "${BASEDIR}"

# CC/CXX exported by diff-instrument.sh — must remain quoted
if [[ -z "${CC:-}" ]]; then
  echo "FATAL: CC not set (run via diff-instrument.sh)" >&2
  exit 1
fi
# shellcheck disable=SC2086
${CC} ${CFLAGS:+"$CFLAGS"} -o program program.c

if [[ -z "${DIFF_ID:-}" ]]; then
  ln -sf "${BASEDIR}/program" "${BINDIR}/unstable"
else
  ln -sf "${BASEDIR}/program" "${BINDIR}/unstable-${DIFF_ID}"
fi
