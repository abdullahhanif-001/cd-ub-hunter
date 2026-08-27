#!/usr/bin/env bash
# select-libtiff.sh — pin-clone libtiff v4.3.0, record SHA
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/config/ephemeral.env" 2>/dev/null || true
bash "${ROOT}/deploy/contabo/pm2-guard.sh"

CAMP="${ROOT}/campaigns/beat-libtiff"
SRC="${CAMP}/src/libtiff"
META="${CAMP}/meta"
mkdir -p "$META" "$(dirname "$SRC")"

if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 --branch v4.3.0 https://gitlab.com/libtiff/libtiff.git "$SRC" || {
    rm -rf "$SRC"
    git clone https://gitlab.com/libtiff/libtiff.git "$SRC"
    git -C "$SRC" checkout v4.3.0
  }
fi

cd "$SRC"
git fetch --tags --depth 1 origin v4.3.0 2>/dev/null || true
git checkout v4.3.0 2>/dev/null || git checkout "v4.3.0"

SHA="$(git rev-parse HEAD)"
echo "$SHA" >"${META}/libtiff.sha"
git log -1 --oneline >"${META}/libtiff.log"
echo "LIBTIFF_PIN=$SHA"
echo "LIBTIFF_SRC=$SRC"
bash "${ROOT}/deploy/contabo/pm2-guard.sh"
echo "SELECT_LIBTIFF_OK"
