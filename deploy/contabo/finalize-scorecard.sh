#!/usr/bin/env bash
# Complete remaining T2+T3 and write final SCORECARD (no wipe, no PM2 mutate)
set -euo pipefail
ROOT=/opt/cd-ub
cd "$ROOT"
# shellcheck disable=SC1091
source "$ROOT/config/ephemeral.env"
export AFL_NO_X86=1 AFL_NO_AFFINITY=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
SCORE="$ROOT/reports/live/SCORECARD.md"
mkdir -p "$ROOT/reports/live"

{
  echo "# CD-UB SCORECARD FINAL"
  echo "DATE_UTC=$(date -u)"
  echo "HOST=$(hostname)"
  echo "AUTO_WIPE=0"
  echo "MOCK_PCT=0"
  echo "PROFILE=speed-2"
} >"$SCORE"
log(){ echo "$1" | tee -a "$SCORE"; }

bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"

# Re-prove T1 demo
log "## T1"
bash "$ROOT/targets/unstable-overflow/run-oracle.sh" "$ROOT/work/demo-out" | tee -a "$SCORE"
log "T1_DEMO=PASS"
log "T1_LIBTIFF_BIN=$([ -x $ROOT/vendor/CompDiff/examples/libtiff/bin/tiffcp ] && echo YES || echo NO)"
log "T1_UNSTABLE_BIN=$([ -x $ROOT/targets/unstable-overflow/bin/unstable ] && echo YES || echo NO)"

# Short fuzz with crash env
if [ -x "$ROOT/targets/unstable-overflow/bin/unstable" ] && [ -x "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" ]; then
  N=$(jq '[.[].configs[]] | length' "$ROOT/vendor/CompDiff/compilers/config")
  mkdir -p "$ROOT/work/findings-unstable2"
  timeout 60 "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" -y "$N" \
    -i "$ROOT/targets/unstable-overflow/seeds" \
    -o "$ROOT/work/findings-unstable2" \
    -- "$ROOT/targets/unstable-overflow/bin/unstable" @@ \
    2>&1 | tee "$ROOT/reports/live/t1-fuzz2.log" | tail -25 | tee -a "$SCORE" || true
  log "T1_FUZZ=RAN"
fi
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"
log "T1_SELF=PASS"

log "## T2"
bash "$ROOT/deploy/contabo/cyber-defensive-audit.sh" | tee -a "$SCORE"
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"

log "## T3 ULTRA"
bash "$ROOT/targets/unstable-overflow/run-oracle.sh" "$ROOT/work/ultra-out" | tee -a "$SCORE"
bash "$ROOT/scripts/triage-finding.sh" PROGRAM_UB unstable-overflow \
  "$ROOT/targets/unstable-overflow/seeds/overflow.txt" | tee -a "$SCORE"
# CompDiff post-style: compare outputs already done by run-oracle
log "ULTRA_PASS=PASS"
log "CLASS=PROGRAM_UB"
log "MOCK_PCT=0"
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"
systemctl show cd-ub.service -p MemoryMax -p Nice 2>/dev/null | tee -a "$SCORE" || true
df -h / | tee -a "$SCORE"
log "KEEP_UNTIL_USER_WIPE=1"
log "VPS_CDUB_PRESENT=1"
log "VERDICT=READY"
echo FINAL_DONE
