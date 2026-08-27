#!/usr/bin/env bash
# build-cdub-libtiff.sh — CompDiff speed-2 instrument tiffcp
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/campaigns/common/campaign-env.sh"
export AFL_NO_X86=1 AFL_NO_AFFINITY=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
bash "${ROOT}/deploy/contabo/pm2-guard.sh"

CAMP="${ROOT}/campaigns/beat-libtiff"
bash "${ROOT}/deploy/contabo/apply-profile.sh" speed-2
bash "${ROOT}/deploy/contabo/patch-compdiff-contabo.sh" || true

if [ ! -x "${ROOT}/vendor/CompDiff/compilers/diff-cc-0" ]; then
  (cd "${ROOT}/vendor/CompDiff/compilers" && source ./build.sh)
fi
test -x "${ROOT}/vendor/CompDiff/aflpp/afl-gcc-fast"
test -x "${ROOT}/vendor/CompDiff/aflpp/afl-fuzz"

bash "${ROOT}/vendor/CompDiff/diff-instrument.sh" "${CAMP}/libtiff-build.sh" \
  2>&1 | tee "${ROOT}/reports/live/beat-libtiff/cdub-instrument.log" | tail -40

test -x "${CAMP}/cdub-bin/tiffcp"
test -x "${CAMP}/cdub-bin/tiffcp-0"
test -x "${CAMP}/cdub-bin/tiffcp-1"
ls -la "${CAMP}/cdub-bin/"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "CDUB_LIBTIFF_INSTRUMENT_OK"
