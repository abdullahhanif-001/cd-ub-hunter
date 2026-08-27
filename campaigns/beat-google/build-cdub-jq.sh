#!/usr/bin/env bash
# build-cdub-jq.sh — CompDiff speed-2 instrument jq
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/campaigns/common/campaign-env.sh"
export AFL_NO_X86=1 AFL_NO_AFFINITY=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
bash "${ROOT}/deploy/contabo/pm2-guard.sh"

CAMP="${ROOT}/campaigns/beat-google"
bash "${ROOT}/deploy/contabo/apply-profile.sh" speed-2
bash "${ROOT}/deploy/contabo/patch-compdiff-contabo.sh" || true

# Ensure diff-cc wrappers exist
if [[ ! -x "${ROOT}/vendor/CompDiff/compilers/diff-cc-0" ]]; then
  (cd "${ROOT}/vendor/CompDiff/compilers" && source ./build.sh)
fi
[[ -x "${ROOT}/vendor/CompDiff/aflpp/afl-gcc-fast" ]]
[[ -x "${ROOT}/vendor/CompDiff/aflpp/afl-fuzz" ]]

# Instrument (1 AFL + N diff binaries)
bash "${ROOT}/vendor/CompDiff/diff-instrument.sh" "${CAMP}/jq-build.sh" \
  2>&1 | tee "${ROOT}/reports/live/beat-google/cdub-instrument.log" | tail -40

[[ -x "${CAMP}/cdub-bin/jq" ]]
[[ -x "${CAMP}/cdub-bin/jq-0" ]]
[[ -x "${CAMP}/cdub-bin/jq-1" ]]
ls -la "${CAMP}/cdub-bin/"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "CDUB_JQ_INSTRUMENT_OK"
