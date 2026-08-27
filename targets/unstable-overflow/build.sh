#!/usr/bin/env bash
# CompDiff-compatible build.sh for unstable-overflow (instrument path)
BASEDIR=$(dirname "$(realpath "$1")")/src/unstable
BINDIR=$(dirname "$(realpath "$1")")/bin
if [ -z "${DIFF_ID:-}" ]; then
  BASEDIR+="-fuzz"
else
  BASEDIR+="-${DIFF_ID}"
fi
rm -rf "${BASEDIR}"
mkdir -p "${BASEDIR}" "${BINDIR}"
cp "$(dirname "$(realpath "$1")")/program.c" "${BASEDIR}/program.c"
cd "${BASEDIR}"
# CC/CXX exported by diff-instrument.sh
${CC} ${CFLAGS:-} -o program program.c
if [ -z "${DIFF_ID:-}" ]; then
  ln -sf "${BASEDIR}/program" "${BINDIR}/unstable"
else
  ln -sf "${BASEDIR}/program" "${BINDIR}/unstable-${DIFF_ID}"
fi
