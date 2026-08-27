# CD-UB Hunter — Production Verification Scorecard

| Field | Value |
|-------|-------|
| Host | `vmi3469243` |
| Date (UTC) | 2026-08-27T17:11:38Z |
| Profile | `speed-2` |
| Maintainer | abdullah |
| **Verdict** | **READY** |

## Phase 1 — Differential Oracle Validation

| Check | Result |
|-------|--------|
| T1.1 Dual-compile oracle | PASS — `gcc -O0`: `R 12 11 10` vs `clang -O3`: `R 10 11 12` |
| Classification | `PROGRAM_UB` |
| T1.2 Unstable binary | YES |
| T1.3 libtiff binary | YES |
| T1.4 Bounded fuzz | RAN (operator-terminated smoke window) |
| Phase 1 aggregate | **PASS** |

## Phase 2 — Co-tenancy Isolation & Safety Conformance

| Check | Result |
|-------|--------|
| PM2 mutation guard | PASS |
| nginx/mongo disruption guard | PASS |
| Path confinement | PASS |
| Secret surface scan | PASS |
| systemd caps | PASS (`MemoryMax=2.5G`) |
| Wipe confirmation gate | PASS |
| PM2 baseline | PASS (`count=6`) |
| Phase 2 aggregate | **PASS** |

## Phase 3 — End-to-End Differential Confirmation

| Check | Result |
|-------|--------|
| Independent oracle re-run | PASS — differential reproduced |
| Triage pipeline | `TRIAGE_OK` / `PROGRAM_UB` |
| Ultra confirmation | PASS |
| Ephemeral retention | `KEEP_UNTIL_USER_WIPE=1` |
| Disk headroom | 82G available on `/` |
| Phase 3 aggregate | **PASS** |

Full evidence: [`tests/evidence/contabo-verification-2026-08-27.md`](../tests/evidence/contabo-verification-2026-08-27.md)
