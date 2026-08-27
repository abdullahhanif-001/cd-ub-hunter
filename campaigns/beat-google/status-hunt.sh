#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname "$0")/../common/status-hunt.sh" beat-google
