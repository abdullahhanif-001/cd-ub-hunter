#!/usr/bin/env bash
set -euo pipefail
export DIFF_POST_ARGS='-M -i @@ out.file'
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
exec bash "${ROOT}/campaigns/common/hunt-runner.sh" beat-libtiff "cdub-bin/tiffcp" "-M" "-i" "@@" "out.file"
