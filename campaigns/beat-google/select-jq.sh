#!/usr/bin/env bash
# select-jq.sh — pin-clone jq, record SHA
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/campaigns/common/campaign-env.sh"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"

CAMP="${ROOT}/campaigns/beat-google"
SRC="${CAMP}/src/jq"
META="${CAMP}/meta"
mkdir -p "$META" "$(dirname "$SRC")"

if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 https://github.com/jqlang/jq.git "$SRC"
  # fetch one more commit depth if needed for submodules later
  git -C "$SRC" submodule update --init --recursive || true
fi

# Prefer a stable tag if present, else HEAD
cd "$SRC"
if git rev-parse jq-1.7.1 >/dev/null 2>&1; then
  git fetch --depth 1 origin tag jq-1.7.1 || true
  git checkout jq-1.7.1 2>/dev/null || git checkout -q HEAD
fi
# init oniguruma submodule required by jq
git submodule update --init --recursive || true

SHA="$(git rev-parse HEAD)"
echo "$SHA" >"${META}/jq.sha"
git log -1 --oneline >"${META}/jq.log"
echo "JQ_PIN=$SHA"
echo "JQ_SRC=$SRC"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "SELECT_JQ_OK"
