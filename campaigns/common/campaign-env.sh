#!/usr/bin/env bash
# campaign-env.sh — load CD-UB root and ephemeral config (required)
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
ENV_FILE="${ROOT}/config/ephemeral.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "FATAL: required config missing: $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
export CDUB_ROOT="$ROOT"
