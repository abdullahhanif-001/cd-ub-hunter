#!/usr/bin/env bash
# bootstrap: extract tar then install (first contact on VPS)
set -euo pipefail

TAR="${1:?tar path}"
INCOMING="${CDUB_INCOMING:-/opt/cd-ub-incoming}"
mkdir -p "$INCOMING"
if ! cp -f "$TAR" "$INCOMING/"; then
  echo "WARN: could not copy tar to $INCOMING (continuing with original path)" >&2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
tar -xzf "$TAR" -C "$TMP"

SRC=""
if [[ -f "$TMP/deploy/contabo/install-from-tar.sh" ]]; then
  SRC="$TMP"
else
  INSTALL_SCRIPT="$(find "$TMP" -type f -name install-from-tar.sh -print -quit)"
  if [[ -z "$INSTALL_SCRIPT" ]]; then
    echo "FATAL: install-from-tar.sh not found in archive" >&2
    exit 1
  fi
  SRC="$(dirname "$(dirname "$(dirname "$INSTALL_SCRIPT")")")"
fi

bash "$SRC/deploy/contabo/install-from-tar.sh" "$TAR"
echo "BOOTSTRAP_OK"
