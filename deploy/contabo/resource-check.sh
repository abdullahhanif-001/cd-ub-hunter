#!/usr/bin/env bash
# resource-check.sh — disk watermark + corpus size
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
WORK="${ROOT}/work"
MAX_MB="${CORPUS_MAX_MB:-2048}"

AVAIL_G="$(df -BG / | awk 'NR==2{gsub(/G/,"",$4); print $4}')"
if [[ "${AVAIL_G%.*}" -lt 40 ]]; then
  echo "FAIL: disk watermark Avail=${AVAIL_G}G < 40G"
  exit 1
fi

if [[ -d "$WORK" ]]; then
  USED_MB="$(du -sm "$WORK" 2>/dev/null | awk '{print $1}')"
  if [[ "${USED_MB:-0}" -gt "$MAX_MB" ]]; then
    echo "FAIL: work corpus ${USED_MB}MB > ${MAX_MB}MB"
    exit 1
  fi
  echo "CORPUS_OK used_mb=$USED_MB max_mb=$MAX_MB"
fi
echo "DISK_OK avail_g=$AVAIL_G"
