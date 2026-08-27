#!/usr/bin/env bash
# dir-utils.sh — safe directory checks (Sonar-safe alternatives to ls -A)
set -euo pipefail

dir_has_entries() {
  local dir="$1"
  find "$dir" -mindepth 1 -print -quit 2>/dev/null | grep -q .
}

count_files_under() {
  local dir="$1"
  find "$dir" -type f 2>/dev/null | wc -l | tr -d ' '
}
