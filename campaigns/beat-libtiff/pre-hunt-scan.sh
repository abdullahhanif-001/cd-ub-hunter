#!/usr/bin/env bash
# pre-hunt-scan.sh — offline CD-UB scan of corpus before AFL (fast beat path)
set -euo pipefail
ROOT="${CDUB_ROOT:-/opt/cd-ub}"
CAMP="${ROOT}/campaigns/beat-libtiff"
OUT="${ROOT}/reports/live/beat-libtiff"
SCAN_OUT="${OUT}/pre_scan_diffs"
mkdir -p "$SCAN_OUT"

T0="${CAMP}/cdub-bin/tiffcp-0"
T1="${CAMP}/cdub-bin/tiffcp-1"
CORP="${CAMP}/corpus"
[[ -x "$T0" && [[ -x "$T1"

FOUND=0
SCANNED=0
: >"${OUT}/pre_scan.log"

for seed in "$CORP"/*; do
  [[ -f "$seed" ]] || continue
  SCANNED=$((SCANNED + 1))
  id="$(basename "$seed" | tr ',' '_' | head -c 80)"
  d="${SCAN_OUT}/${id}"
  mkdir -p "$d"
  rm -f "$d/out0.file" "$d/out1.file"
  timeout 10 "$T0" -M -i "$seed" "$d/out0.file" >"$d/err0.txt" 2>&1 || true
  timeout 10 "$T1" -M -i "$seed" "$d/out1.file" >"$d/err1.txt" 2>&1 || true
  if [[ -f "$d/out0.file" ]] && [[ -f "$d/out1.file" ]]; then
    if ! cmp -s "$d/out0.file" "$d/out1.file"; then
      cp -f "$seed" "$SCAN_OUT/input_${id}"
      FOUND=$((FOUND + 1))
      echo "PRESCAN_DIFF id=$id" | tee -a "${OUT}/pre_scan.log"
    fi
  elif ! cmp -s "$d/err0.txt" "$d/err1.txt" 2>/dev/null; then
    cp -f "$seed" "$SCAN_OUT/input_${id}"
    FOUND=$((FOUND + 1))
    echo "PRESCAN_ERR_DIFF id=$id" | tee -a "${OUT}/pre_scan.log"
  fi
done

echo "PRESCAN_SCANNED=$SCANNED" | tee "${OUT}/pre_scan_summary.txt"
echo "PRESCAN_FOUND=$FOUND" | tee -a "${OUT}/pre_scan_summary.txt"

# Copy prescan hits into cdub_diffs for confirm pipeline
mkdir -p "${OUT}/cdub_diffs"
for f in "$SCAN_OUT"/input_*; do
  [[ -f "$f" ]] || continue
  cp -f "$f" "${OUT}/cdub_diffs/$(basename "$f")"
done

bash "${ROOT}/deploy/contabo/pm2-guard.sh" 2>/dev/null || true
echo "PRE_HUNT_SCAN_DONE found=$FOUND scanned=$SCANNED"
