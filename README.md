# CD-UB Hunter (CompDiff one-click on Contabo)

Thin Contabo-safe wrapper around upstream [CompDiff](https://github.com/shao-hua-li/CompDiff) (ASPLOS'23). No greenfield fuzzer.

**Maintainer:** abdullah

## Pin

See [VENDOR_PIN.txt](VENDOR_PIN.txt) — commit `2b2cdd3`.

## One-click (copy-paste)

```bash
# --- GitHub source (lean; CompDiff cloned on first run) ---
git clone https://github.com/abdullahhanif-001/cd-ub-hunter.git /opt/cd-ub
cd /opt/cd-ub
bash scripts/oneclick/cdub-oneclick.sh

# --- Or: release tarball (includes vendored CompDiff) ---
# curl -L -o /opt/cd-ub-incoming/cd-ub.tar.gz \
#   https://github.com/abdullahhanif-001/cd-ub-hunter/releases/latest/download/cd-ub-2b2cdd3fa31f.tar.gz
# bash deploy/contabo/install-from-tar.sh /opt/cd-ub-incoming/cd-ub.tar.gz
# bash /opt/cd-ub/scripts/oneclick/cdub-oneclick.sh
```

Defaults: `speed-2` (`gcc -O0` + `clang -O3`), `AUTO_WIPE=0`, PM2×6 guards, CPUQuota 50%, MemoryMax 2.5G.

CompDiff is cloned on Linux at pin from `VENDOR_PIN.txt` (not stored in git). Uses `afl-gcc-fast` (gcc plugin) because CompDiff's bundled AFL++ LLVM mode needs patches for clang 18.

## Pack for Contabo (from dev host)

```bash
bash deploy/contabo/pack.sh
scp cd-ub-*.tar.gz contabo-server:/opt/cd-ub-incoming/
ssh contabo-server
bash /opt/cd-ub/deploy/contabo/install-from-tar.sh /opt/cd-ub-incoming/cd-ub-*.tar.gz
bash /opt/cd-ub/scripts/oneclick/cdub-oneclick.sh
```

## Quality gates

SonarQube analysis scope: owned wrapper only (`vendor/` excluded). Run `bash tests/run-suite.sh` before analysis.


See [tests/TEST_PLAN.md](tests/TEST_PLAN.md) for the formal phase matrix. Production evidence: [tests/evidence/contabo-verification-2026-08-27.md](tests/evidence/contabo-verification-2026-08-27.md).

```bash
bash tests/run-suite.sh          # full Phase 1–3 on deployed host
bash tests/run-oracle-local.sh   # portable oracle only (gcc + clang)
```

## Verified Contabo scorecard

See [reports/SCORECARD.md](reports/SCORECARD.md) — `VERDICT=READY`, `PHASE3_CONFIRMATION=PASS`, `MOCK_PCT=0`, PM2 guard held, `/opt/cd-ub` kept until you order wipe.

## Wipe

**Forbidden unless you explicitly order it.**

```bash
CONFIRM_USER_WIPE=1 WIPE_REASON='user ordered wipe' bash /opt/cd-ub/deploy/contabo/wipe-ephemeral.sh
```

## Profiles

- `profiles/speed-2.json` — default
- `profiles/full-10.json` — requires `ALLOW_FULL_10=1` + resource gates
