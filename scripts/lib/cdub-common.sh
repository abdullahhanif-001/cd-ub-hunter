#!/usr/bin/env bash
# cdub-common.sh — shared helpers (quoting, paths, optional steps)
# shellcheck shell=bash
set -euo pipefail

cdub_root() {
  printf '%s\n' "${CDUB_ROOT:-/opt/cd-ub}"
}

cdub_repo_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s\n' "$here"
}

cdub_require_file() {
  local f="$1"
  if [ ! -f "$f" ]; then
    echo "FATAL: required file missing: $f" >&2
    return 1
  fi
}

cdub_source_env() {
  local root="$1"
  local env_file="${root}/config/ephemeral.env"
  cdub_require_file "$env_file"
  # shellcheck disable=SC1090
  source "$env_file"
}

cdub_safe_cd() {
  local dir="$1"
  if ! cd "$dir"; then
    echo "FATAL: cannot cd to $dir" >&2
    return 1
  fi
}

# Run a command; log and continue on non-zero exit (replaces bare '|| true')
cdub_optional() {
  local label="$1"
  shift
  if ! "$@"; then
    echo "WARN: optional step skipped ($label)" >&2
    return 0
  fi
}

# Run a command expected to fail (e.g. wipe gate probe)
cdub_expect_fail() {
  if "$@"; then
    echo "FATAL: expected failure but command succeeded: $*" >&2
    return 1
  fi
  return 0
}

cdub_dir_nonempty() {
  local dir="$1"
  find "$dir" -mindepth 1 -print -quit 2>/dev/null | grep -q .
}

cdub_count_files() {
  local dir="$1"
  find "$dir" -type f 2>/dev/null | wc -l | tr -d ' '
}

cdub_diff_config_count() {
  local root="$1"
  jq '[.[].configs[]] | length' "${root}/vendor/CompDiff/compilers/config"
}
