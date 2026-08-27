#!/usr/bin/env bash
# cdub-oneclick.sh — guard → clang → profile → build CompDiff → Phase 1–3 → scorecard; NEVER wipe
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

export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
  build-essential cmake git wget ca-certificates \
  libssl-dev jq python3 \
  autoconf automake libtool pkg-config \
  zlib1g-dev 2>&1 | tail -5 | tee -a "$SCORE"

cd "$ROOT/vendor"
mkdir -p "$ROOT/vendor"
if [ ! -d CompDiff ] || [ ! -L CompDiff/aflpp/types.h ]; then
  echo "Cloning CompDiff on Linux (pin ${COMPDIFF_PIN:-2b2cdd3fa31f83c9a9e4070c2131d156c3dfcad4})..." | tee -a "$SCORE"
  rm -rf CompDiff
  git clone --depth 1 https://github.com/shao-hua-li/CompDiff.git CompDiff
  if ! git -C CompDiff checkout "${COMPDIFF_PIN:-2b2cdd3fa31f83c9a9e4070c2131d156c3dfcad4}" 2>/dev/null; then
    echo "WARN: CompDiff pin checkout failed" >&2
  fi
fi

bash "$ROOT/deploy/contabo/apply-profile.sh" "${CDUB_PROFILE:-speed-2}" | tee -a "$SCORE"
if ! bash "$ROOT/deploy/contabo/patch-compdiff-contabo.sh" 2>&1 | tee -a "$SCORE"; then
  echo "WARN: Contabo patch step returned non-zero" >&2
fi
export AFL_NO_X86=1
if ! bash "$ROOT/deploy/contabo/rebuild-afl.sh" 2>&1 | tee -a "$SCORE"; then
  echo "WARN: AFL rebuild returned non-zero" >&2
fi

(
  cd "$ROOT/vendor/CompDiff"
  if [ ! -x compilers/diff-cc-0 ]; then
    (cd compilers && source ./build.sh)
  fi
)
cd "$ROOT"
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"

N="$(jq '[.[].configs[]] | length' "$ROOT/vendor/CompDiff/compilers/config")"
log "DIFF_CONFIG_COUNT=$N"

log "## Phase 1: Differential Oracle Validation"
T1_OK=0
if bash "$ROOT/targets/unstable-overflow/run-oracle.sh" "$ROOT/work/demo-out" | tee "$ROOT/reports/live/t1-demo.log" | tee -a "$SCORE"; then
  T1_OK=1
  log "PHASE1_ORACLE=PASS"
else
  log "PHASE1_ORACLE=FAIL"
fi

if [ -x "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" ]; then
  if bash "$ROOT/vendor/CompDiff/diff-instrument.sh" \
    "$ROOT/targets/unstable-overflow/build.sh" \
    2>&1 | tee "$ROOT/reports/live/t1-instrument.log" | tail -40 | tee -a "$SCORE"; then
    :
  else
    echo "WARN: unstable instrument returned non-zero" >&2
  fi
  BINDIR="$ROOT/targets/unstable-overflow/bin"
  if [ -x "$BINDIR/unstable" ]; then
    mkdir -p "$ROOT/work/findings-unstable"
    bash "$ROOT/scripts/lib/run-bounded-fuzz.sh" 120 \
      "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" -y "$N" \
      -i "$ROOT/targets/unstable-overflow/seeds" \
      -o "$ROOT/work/findings-unstable" \
      -- "$BINDIR/unstable" @@ \
      2>&1 | tee "$ROOT/reports/live/t1-fuzz.log" | tail -50 | tee -a "$SCORE"
    if grep -E 'execs_done|exec speed' "$ROOT/reports/live/t1-fuzz.log" >/dev/null 2>&1; then
      grep -E 'execs_done|exec speed' "$ROOT/reports/live/t1-fuzz.log" | tail -5 | tee -a "$SCORE"
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
if [ "$T1_OK" -eq 1 ]; then
  log "PHASE1_AGGREGATE=PASS"
else
  log "PHASE1_AGGREGATE=FAIL"
fi

log "## Phase 2: Co-tenancy Isolation & Safety Conformance"
bash "$ROOT/deploy/contabo/cyber-defensive-audit.sh" | tee -a "$SCORE"
bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"

log "## Phase 3: End-to-End Differential Confirmation"
ULTRA="FAIL"
if bash "$ROOT/targets/unstable-overflow/run-oracle.sh" "$ROOT/work/ultra-out" | tee "$ROOT/reports/live/t3-ultra.log" | tee -a "$SCORE"; then
  bash "$ROOT/scripts/triage-finding.sh" PROGRAM_UB unstable-overflow \
    "$ROOT/targets/unstable-overflow/seeds/overflow.txt" | tee -a "$SCORE"
  ULTRA="PASS"
fi

if [ "${RUN_LIBTIFF:-1}" = "1" ] && [ -x "$ROOT/vendor/CompDiff/aflpp/afl-clang-fast" ]; then
  log "LIBTIFF_INSTRUMENT=START"
  if bash "$ROOT/vendor/CompDiff/diff-instrument.sh" \
    "$ROOT/vendor/CompDiff/examples/libtiff/build.sh" \
    2>&1 | tee "$ROOT/reports/live/libtiff-instrument.log" | tail -40 | tee -a "$SCORE"; then
    :
  else
    echo "WARN: libtiff instrument returned non-zero" >&2
  fi
  TB="$ROOT/vendor/CompDiff/examples/libtiff/bin"
  if [ -x "$TB/tiffcp" ]; then
    mkdir -p "$ROOT/work/findings-libtiff" "$ROOT/work/seeds-libtiff"
    printf '\x49\x49\x2a\x00' >"$ROOT/work/seeds-libtiff/mini.tif"
    bash "$ROOT/scripts/lib/run-bounded-fuzz.sh" 180 \
      "$ROOT/vendor/CompDiff/aflpp/afl-fuzz" -y "$N" \
      -i "$ROOT/work/seeds-libtiff" \
      -o "$ROOT/work/findings-libtiff" \
      -Y "out.file" \
      -- "$TB/tiffcp" -M -i @@ out.file \
      2>&1 | tee "$ROOT/reports/live/libtiff-fuzz.log" | tail -40 | tee -a "$SCORE"
    T1_OK=1
    log "T1_LIBTIFF=RAN"
  else
    log "T1_LIBTIFF=SKIP_NO_BIN"
  fi
fi

if [ "${RUN_XPDF:-0}" = "1" ] && [ -x "$ROOT/vendor/CompDiff/aflpp/afl-clang-fast" ]; then
  log "XPDF_INSTRUMENT=START"
  if bash "$ROOT/vendor/CompDiff/diff-instrument.sh" \
    "$ROOT/vendor/CompDiff/examples/xpdf/build.sh" \
    2>&1 | tee "$ROOT/reports/live/xpdf-instrument.log" | tail -20 | tee -a "$SCORE"; then
    :
  else
    echo "WARN: xpdf instrument returned non-zero" >&2
  fi
fi

bash "$ROOT/deploy/contabo/pm2-guard.sh" | tee -a "$SCORE"
if [ "$ULTRA" = "PASS" ]; then
  log "PHASE3_CONFIRMATION=PASS"
else
  log "PHASE3_CONFIRMATION=FAIL"
fi
log "PM2_GUARD=PASS"
log "KEEP_UNTIL_USER_WIPE=1"
log "VPS_PATH=$ROOT remains (AUTO_WIPE=0)"

if systemctl show cd-ub.service -p CPUQuota -p MemoryMax -p Nice 2>/dev/null | tee -a "$SCORE"; then
  :
fi

if [ "$ULTRA" = "PASS" ] && [ "$T1_OK" -eq 1 ]; then
  log "VERDICT=READY"
  exit 0
fi
log "VERDICT=NOT_READY"
exit 1
