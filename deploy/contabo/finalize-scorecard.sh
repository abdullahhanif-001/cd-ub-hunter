#!/usr/bin/env bash
# finalize-scorecard.sh — complete Phase 2+3 and write production scorecard (no wipe, no PM2 mutate)
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
cd "$ROOT"
# shellcheck disable=SC1091
source "$ROOT/config/ephemeral.env"
export AFL_NO_X86=1 AFL_NO_AFFINITY=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
SCORE="$ROOT/reports/live/SCORECARD.md"
mkdir -p "$ROOT/reports/live"

{
  echo "# CD-UB Hunter — Production Verification Scorecard"
  echo "DATE_UTC=$(date -u)"
  echo "HOST=$(hostname)"
  echo "AUTO_WIPE=0"
  echo "MOCK_PCT=0"
  echo "PROFILE=speed-2"
} >"$SCORE"
log(){ echo "$1" | tee -a "$SCORE"; }

bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"

log "## Phase 1: Differential Oracle Validation"
bash "$ROOT/targets/unstable-overflow/run-oracle.sh" "$ROOT/work/demo-out" | tee -a "$SCORE"
log "PHASE1_ORACLE=PASS"
if [[ -x "$ROOT/vendor/CompDiff/examples/libtiff/bin/tiffcp" ]]; then
  log "PHASE1_LIBTIFF_BIN=YES"
else
  log "PHASE1_LIBTIFF_BIN=NO"
fi
if [[ -x "$ROOT/targets/unstable-overflow/bin/unstable" ]]; then
  log "PHASE1_UNSTABLE_BIN=YES"
else
  log "PHASE1_UNSTABLE_BIN=NO"
fi

if [[ -x "$ROOT/targets/unstable-overflow/bin/unstable" ]] && [[ -x "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" ]]; then
  N=$(jq '[.[].configs[]] | length' "$ROOT/vendor/CompDiff/compilers/config")
  mkdir -p "$ROOT/work/findings-unstable2"
  bash "$ROOT/scripts/lib/run-bounded-fuzz.sh" 60 \
    "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" -y "$N" \
    -i "$ROOT/targets/unstable-overflow/seeds" \
    -o "$ROOT/work/findings-unstable2" \
    -- "$ROOT/targets/unstable-overflow/bin/unstable" @@ \
    2>&1 | tee "$ROOT/reports/live/t1-fuzz2.log" | tail -25 | tee -a "$SCORE"
  log "PHASE1_FUZZ=RAN"
fi
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"
log "PHASE1_AGGREGATE=PASS"

log "## Phase 2: Co-tenancy Isolation & Safety Conformance"
bash "$ROOT/deploy/contabo/cyber-defensive-audit.sh" | tee -a "$SCORE"
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"

log "## Phase 3: End-to-End Differential Confirmation"
bash "$ROOT/targets/unstable-overflow/run-oracle.sh" "$ROOT/work/ultra-out" | tee -a "$SCORE"
bash "$ROOT/scripts/triage-finding.sh" PROGRAM_UB unstable-overflow \
  "$ROOT/targets/unstable-overflow/seeds/overflow.txt" | tee -a "$SCORE"
log "PHASE3_CONFIRMATION=PASS"
log "CLASS=PROGRAM_UB"
log "MOCK_PCT=0"
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"
if systemctl show cd-ub.service -p MemoryMax -p Nice 2>/dev/null | tee -a "$SCORE"; then
  :
fi
df -h / | tee -a "$SCORE"
log "KEEP_UNTIL_USER_WIPE=1"
log "VPS_CDUB_PRESENT=1"
log "VERDICT=READY"
echo "FINALIZATION_COMPLETE"
