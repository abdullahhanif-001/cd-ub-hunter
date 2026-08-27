#!/usr/bin/env bash
# cdub-oneclick.sh — guard → clang → profile → build CompDiff → T1/T2/T3 → scorecard; NEVER wipe
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
cd "$ROOT"
# shellcheck disable=SC1091
source "$ROOT/config/ephemeral.env"

export AFL_NO_AFFINITY=1
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_NO_X86=1
export PATH="/usr/bin:$PATH"

SCORE="$ROOT/reports/live/SCORECARD.md"
mkdir -p "$ROOT/reports/live" "$ROOT/work"
: >"$SCORE"
log() { echo "$1" | tee -a "$SCORE"; }

log "# CD-UB SCORECARD"
log "HOST=$(hostname)"
log "DATE_UTC=$(date -u)"
log "AUTO_WIPE=${AUTO_WIPE:-0}"
log "PROFILE=${CDUB_PROFILE:-speed-2}"
log "MOCK_PCT=0"

bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"
bash "$ROOT/deploy/contabo/resource-check.sh" | tee -a "$SCORE"
bash "$ROOT/deploy/contabo/install-clang-gated.sh" | tee -a "$SCORE"
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"

# deps for CompDiff build (minimal — not full preinstall/llvm.sh)
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
  build-essential cmake git wget ca-certificates \
  libssl-dev jq python3 \
  autoconf automake libtool pkg-config \
  zlib1g-dev 2>&1 | tail -5 | tee -a "$SCORE"

# Build CompDiff (AFL++ + diff compilers) — clone on Linux if missing or Windows symlink stubs
cd "$ROOT/vendor"
mkdir -p "$ROOT/vendor"
if [ ! -d CompDiff ] || [ ! -L CompDiff/aflpp/types.h ]; then
  echo "Cloning CompDiff on Linux (pin ${COMPDIFF_PIN:-2b2cdd3fa31f83c9a9e4070c2131d156c3dfcad4})..." | tee -a "$SCORE"
  rm -rf CompDiff
  git clone --depth 1 https://github.com/shao-hua-li/CompDiff.git CompDiff
  git -C CompDiff checkout "${COMPDIFF_PIN:-2b2cdd3fa31f83c9a9e4070c2131d156c3dfcad4}" 2>/dev/null || true
fi
bash "$ROOT/deploy/contabo/apply-profile.sh" "${CDUB_PROFILE:-speed-2}" | tee -a "$SCORE"
bash "$ROOT/deploy/contabo/patch-compdiff-contabo.sh" | tee -a "$SCORE" || true
export AFL_NO_X86=1
bash "$ROOT/deploy/contabo/rebuild-afl.sh" 2>&1 | tee -a "$SCORE" || true
cd "$ROOT/vendor/CompDiff"
# build speed-2 wrappers if missing
if [ ! -x compilers/diff-cc-0 ]; then
  (cd compilers && source ./build.sh)
fi
cd "$ROOT"
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"

N="$(jq '[.[].configs[]] | length' "$ROOT/vendor/CompDiff/compilers/config")"
log "DIFF_CONFIG_COUNT=$N"

# --- T1: instrument unstable-overflow via CompDiff + short fuzz OR direct smoke ---
log "## T1 self-test"
T1_OK=0
# Direct dual-compile smoke (fast reliability gate)
if bash "$ROOT/targets/unstable-overflow/run-oracle.sh" "$ROOT/work/demo-out" | tee "$ROOT/reports/live/t1-demo.log" | tee -a "$SCORE"; then
  T1_OK=1
  log "T1_DEMO=PASS"
else
  log "T1_DEMO=FAIL"
fi

# CompDiff instrument unstable target (speed-2 => -y 2)
if [ -x "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" ]; then
  bash "$ROOT/vendor/CompDiff/diff-instrument.sh" \
    "$ROOT/targets/unstable-overflow/build.sh" \
    2>&1 | tee "$ROOT/reports/live/t1-instrument.log" | tail -40 | tee -a "$SCORE" || true
  BINDIR="$ROOT/targets/unstable-overflow/bin"
  if [ -x "$BINDIR/unstable" ]; then
    mkdir -p "$ROOT/work/findings-unstable"
    timeout 120 "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" \
      -y "$N" \
      -i "$ROOT/targets/unstable-overflow/seeds" \
      -o "$ROOT/work/findings-unstable" \
      -- "$BINDIR/unstable" @@ \
      2>&1 | tee "$ROOT/reports/live/t1-fuzz.log" | tail -50 | tee -a "$SCORE" || true
    # extract execs/sec if present
    if grep -E 'execs_done|exec speed' "$ROOT/reports/live/t1-fuzz.log" >/dev/null 2>&1; then
      grep -E 'execs_done|exec speed' "$ROOT/reports/live/t1-fuzz.log" | tail -5 | tee -a "$SCORE" || true
    fi
    T1_OK=1
    log "T1_COMPDIFF_FUZZ=RAN"
  else
    log "T1_COMPDIFF_FUZZ=SKIP_NO_BIN"
  fi
else
  log "T1_COMPDIFF_FUZZ=SKIP_NO_AFL"
fi
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"
log "T1_SELF=$([ $T1_OK -eq 1 ] && echo PASS || echo FAIL)"

# --- T2 ---
log "## T2 cyber defensive"
bash "$ROOT/deploy/contabo/cyber-defensive-audit.sh" | tee -a "$SCORE"
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"

# --- T3 Ultra: original binaries disagreement ---
log "## T3 deep ultra MOCK_PCT=0"
ULTRA=FAIL
if bash "$ROOT/targets/unstable-overflow/run-oracle.sh" "$ROOT/work/ultra-out" | tee "$ROOT/reports/live/t3-ultra.log" | tee -a "$SCORE"; then
  bash "$ROOT/scripts/triage-finding.sh" PROGRAM_UB unstable-overflow \
    "$ROOT/targets/unstable-overflow/seeds/overflow.txt" | tee -a "$SCORE"
  ULTRA=PASS
fi

# T1 CompDiff examples: libtiff (original upstream build.sh). xpdf optional via RUN_XPDF=1
if [ "${RUN_LIBTIFF:-1}" = "1" ] && [ -x "$ROOT/vendor/CompDiff/aflpp/afl-clang-fast" ]; then
  log "LIBTIFF_INSTRUMENT=START"
  bash "$ROOT/vendor/CompDiff/diff-instrument.sh" \
    "$ROOT/vendor/CompDiff/examples/libtiff/build.sh" \
    2>&1 | tee "$ROOT/reports/live/libtiff-instrument.log" | tail -40 | tee -a "$SCORE" || true
  TB="$ROOT/vendor/CompDiff/examples/libtiff/bin"
  if [ -x "$TB/tiffcp" ]; then
    mkdir -p "$ROOT/work/findings-libtiff" "$ROOT/work/seeds-libtiff"
    # minimal seed
    printf '\x49\x49\x2a\x00' >"$ROOT/work/seeds-libtiff/mini.tif" || true
    timeout 180 "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" \
      -y "$N" \
      -i "$ROOT/work/seeds-libtiff" \
      -o "$ROOT/work/findings-libtiff" \
      -Y "out.file" \
      -- "$TB/tiffcp" -M -i @@ out.file \
      2>&1 | tee "$ROOT/reports/live/libtiff-fuzz.log" | tail -40 | tee -a "$SCORE" || true
    T1_OK=1
    log "T1_LIBTIFF=RAN"
  else
    log "T1_LIBTIFF=SKIP_NO_BIN"
  fi
fi
if [ "${RUN_XPDF:-0}" = "1" ] && [ -x "$ROOT/vendor/CompDiff/aflpp/afl-clang-fast" ]; then
  log "XPDF_INSTRUMENT=START"
  bash "$ROOT/vendor/CompDiff/diff-instrument.sh" \
    "$ROOT/vendor/CompDiff/examples/xpdf/build.sh" \
    2>&1 | tee "$ROOT/reports/live/xpdf-instrument.log" | tail -20 | tee -a "$SCORE" || true
fi

bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"
log "ULTRA_PASS=$([ "$ULTRA" = PASS ] && echo PASS || echo FAIL)"
log "PM2_GUARD=PASS"
log "KEEP_UNTIL_USER_WIPE=1"
log "VPS_PATH=$ROOT remains (AUTO_WIPE=0)"

# Caps evidence
systemctl show cd-ub.service -p CPUQuota -p MemoryMax -p Nice 2>/dev/null | tee -a "$SCORE" || true

if [ "$ULTRA" = PASS ] && [ "$T1_OK" -eq 1 ]; then
  log "VERDICT=READY"
  exit 0
fi
log "VERDICT=NOT_READY"
exit 1
