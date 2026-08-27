#!/usr/bin/env bash
set -euo pipefail
export DIFF_POST_ARGS='. @@'
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
exec bash "${ROOT}/campaigns/common/hunt-runner.sh" beat-google "cdub-bin/jq" "." "@@"
