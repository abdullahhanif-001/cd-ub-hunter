#!/usr/bin/env bash
# apply-profile.sh — copy speed-2 or full-10 into CompDiff compilers/config
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROFILE_NAME="${1:-${CDUB_PROFILE:-speed-2}}"
PROFILE_FILE="${REPO_ROOT}/profiles/${PROFILE_NAME}.json"
TARGET="${REPO_ROOT}/vendor/CompDiff/compilers/config"

if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "FAIL: missing profile $PROFILE_FILE"
  exit 1
fi

# Gate full-10
if [[ "$PROFILE_NAME" = "full-10" ]]; then
  if [[ "${ALLOW_FULL_10:-0}" != "1" ]]; then
    echo "FAIL: full-10 requires ALLOW_FULL_10=1 and resource checks"
    exit 1
  fi
  AVAIL_G="$(df -BG / | awk 'NR==2{gsub(/G/,"",$4); print $4}')"
  MEM_G="$(awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)"
  python3 - <<PY || { echo "FAIL: full-10 resource gate"; exit 1; }
avail=float("${AVAIL_G}")
mem=float("${MEM_G}")
assert avail >= 50.0, avail
assert mem >= 4.0, mem
print("full-10 gates OK", avail, mem)
PY
fi

cp "$PROFILE_FILE" "$TARGET"
echo "APPLIED_PROFILE=$PROFILE_NAME -> $TARGET"
# count configs
N="$(jq '[.[].configs[]] | length' "$TARGET")"
echo "DIFF_CONFIG_COUNT=$N"
