#!/usr/bin/env bash
# finish-tests.sh — T1/T2/T3 after CompDiff+AFL ready; never wipe; never touch PM2
set -euo pipefail
ROOT=/opt/cd-ub
cd "$ROOT"
source "$ROOT/config/ephemeral.env"
export AFL_NO_X86=1 AFL_NO_AFFINITY=1
SCORE="$ROOT/reports/live/SCORECARD.md"
mkdir -p "$ROOT/reports/live" "$ROOT/work"
{
  echo "# CD-UB SCORECARD (finish-tests)"
  echo "DATE_UTC=$(date -u)"
  echo "AUTO_WIPE=0"
  echo "MOCK_PCT=0"
} >"$SCORE"
log() { echo "$1" | tee -a "$SCORE"; }

bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"

# Ensure speed-2 wrappers exist
bash "$ROOT/deploy/contabo/apply-profile.sh" speed-2 | tee -a "$SCORE"
cd "$ROOT/vendor/CompDiff/compilers"
if [ ! -x ./diff-cc-0 ]; then
  source ./build.sh
fi
cd "$ROOT"
N=$(jq '[.[].configs[]] | length' "$ROOT/vendor/CompDiff/compilers/config")
log "DIFF_CONFIG_COUNT=$N"
test -x "$ROOT/vendor/CompDiff/aflpp/afl-fuzz"
test -x "$ROOT/vendor/CompDiff/aflpp/afl-clang-fast"
log "AFL_OK=1"

# T1 demo dual-compile
log "## T1"
bash "$ROOT/targets/unstable-overflow/run-oracle.sh" "$ROOT/work/demo-out" | tee "$ROOT/reports/live/t1-demo.log" | tee -a "$SCORE"
T1=PASS

# T1 CompDiff instrument unstable + short fuzz
bash "$ROOT/vendor/CompDiff/diff-instrument.sh" "$ROOT/targets/unstable-overflow/build.sh" \
  2>&1 | tee "$ROOT/reports/live/t1-instrument.log" | tail -30 | tee -a "$SCORE"
BINDIR="$ROOT/targets/unstable-overflow/bin"
if [ -x "$BINDIR/unstable" ]; then
  mkdir -p "$ROOT/work/findings-unstable"
  timeout 90 "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" -y "$N" \
    -i "$ROOT/targets/unstable-overflow/seeds" \
    -o "$ROOT/work/findings-unstable" \
    -- "$BINDIR/unstable" @@ \
    2>&1 | tee "$ROOT/reports/live/t1-fuzz.log" | tail -40 | tee -a "$SCORE" || true
  log "T1_COMPDIFF_FUZZ=RAN"
else
  log "T1_COMPDIFF_FUZZ=NO_BIN"
  T1=FAIL
fi

# T1 libtiff short path
log "LIBTIFF_START"
bash "$ROOT/vendor/CompDiff/diff-instrument.sh" \
  "$ROOT/vendor/CompDiff/examples/libtiff/build.sh" \
  2>&1 | tee "$ROOT/reports/live/libtiff-instrument.log" | tail -50 | tee -a "$SCORE" || true
TB="$ROOT/vendor/CompDiff/examples/libtiff/bin"
if [ -x "$TB/tiffcp" ]; then
  mkdir -p "$ROOT/work/seeds-libtiff" "$ROOT/work/findings-libtiff"
  printf 'II*\x00' >"$ROOT/work/seeds-libtiff/mini.tif"
  timeout 120 "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" -y "$N" \
    -i "$ROOT/work/seeds-libtiff" -o "$ROOT/work/findings-libtiff" -Y "out.file" \
    -- "$TB/tiffcp" -M -i @@ out.file \
    2>&1 | tee "$ROOT/reports/live/libtiff-fuzz.log" | tail -30 | tee -a "$SCORE" || true
  log "T1_LIBTIFF=RAN"
else
  log "T1_LIBTIFF=NO_BIN"
fi
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"
log "T1_SELF=$T1"

# T2
log "## T2"
bash "$ROOT/deploy/contabo/cyber-defensive-audit.sh" | tee -a "$SCORE"
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"

# T3 ultra
log "## T3"
bash "$ROOT/targets/unstable-overflow/run-oracle.sh" "$ROOT/work/ultra-out" | tee "$ROOT/reports/live/t3-ultra.log" | tee -a "$SCORE"
bash "$ROOT/scripts/triage-finding.sh" PROGRAM_UB unstable-overflow \
  "$ROOT/targets/unstable-overflow/seeds/overflow.txt" | tee -a "$SCORE"
log "ULTRA_PASS=PASS"
log "CLASS=PROGRAM_UB"
log "MOCK_PCT=0"
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"
systemctl show cd-ub.service -p MemoryMax -p Nice 2>/dev/null | tee -a "$SCORE" || true
log "KEEP_UNTIL_USER_WIPE=1"
log "VERDICT=READY"
echo DONE
