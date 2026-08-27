#!/usr/bin/env bash
# bootstrap: extract tar then install (first contact on Contabo)
set -euo pipefail
TAR="${1:?tar path}"
mkdir -p /opt/cd-ub-incoming
cp -f "$TAR" /opt/cd-ub-incoming/ || true
TMP="$(mktemp -d)"
tar -xzf "$TAR" -C "$TMP"
if [ -f "$TMP/deploy/contabo/install-from-tar.sh" ]; then
  SRC="$TMP"
else
  SRC="$(find "$TMP" -type f -name install-from-tar.sh | head -1 | xargs dirname | xargs dirname | xargs dirname)"
fi
bash "$SRC/deploy/contabo/install-from-tar.sh" "$TAR"
echo "BOOTSTRAP_OK"
