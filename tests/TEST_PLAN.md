# CD-UB Hunter — Verification Test Plan

**Maintainer:** abdullah  
**Scope:** VPS-safe CompDiff wrapper (not upstream CompDiff/AFL++ unit tests)  
**Acceptance gate:** `VERDICT=READY` requires Phase 1 + Phase 2 + Phase 3 PASS with `MOCK_PCT=0`

## Test matrix

| Phase | ID | Objective | Entry criteria | Pass criteria |
|-------|-----|-----------|----------------|---------------|
| 1 | T1.1 | Differential oracle — dual-compile smoke | `gcc`, `clang` on PATH | `gcc -O0` vs `clang -O3` disagree on canonical seed; `CLASS=PROGRAM_UB` |
| 1 | T1.2 | CompDiff instrumentation | AFL++ built; `diff-instrument.sh` | `targets/unstable-overflow/bin/unstable` executable |
| 1 | T1.3 | Bounded differential fuzz | T1.2 PASS | `afl-fuzz -y N` runs without abort; PM2 guard unchanged |
| 1 | T1.4 | libtiff integration (optional) | `RUN_LIBTIFF=1` | `tiffcp` instrumented; short fuzz session completes |
| 2 | T2.1 | Wrapper isolation audit | Deploy tree present | No PM2/nginx/mongo mutation commands in wrappers |
| 2 | T2.2 | Path confinement | — | No `/opt` escape to co-resident app paths |
| 2 | T2.3 | Secret surface scan | — | No `.pem`, `id_rsa*`, `.env.local` in owned tree |
| 2 | T2.4 | Resource caps | `cd-ub.service` installed | `CPUQuota`, `MemoryMax` visible via systemd |
| 2 | T2.5 | Destructive-op gate | — | `wipe-ephemeral.sh` refuses without `CONFIRM_USER_WIPE=1` |
| 2 | T2.6 | PM2 co-tenancy guard | PM2 running | `pm2-guard.sh` PASS; restart count baseline held |
| 3 | T3.1 | End-to-end differential confirmation | T1.1 oracle reproducible | Same disagreement on independent output dir |
| 3 | T3.2 | Finding triage pipeline | T3.1 PASS | `triage-finding.sh` emits `TRIAGE_OK` with `PROGRAM_UB` |
| 3 | T3.3 | Production readiness | All above | `ULTRA_PASS=PASS`, `KEEP_UNTIL_USER_WIPE=1`, disk headroom logged |

## Execution

```bash
# Full suite (requires /opt/cd-ub deploy + CompDiff built)
bash tests/run-suite.sh

# Local oracle only (gcc + clang required)
bash tests/run-oracle-local.sh

# Safety conformance only
bash tests/run-safety-audit.sh
```

## Evidence

Recorded production verification: [`tests/evidence/vps-verification-2026-08-27.md`](evidence/vps-verification-2026-08-27.md)
