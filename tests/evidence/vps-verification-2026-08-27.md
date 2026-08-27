# Production Verification Record — Linux VPS

| Field | Value |
|-------|-------|
| Host | `vmi3469243` |
| Date (UTC) | 2026-08-27T17:11:38Z |
| Profile | `speed-2` (`gcc -O0` + `clang -O3`) |
| Maintainer | abdullah |
| Verdict | **READY** |

## Phase 1 — Differential Oracle Validation

### T1.1 Dual-compile smoke (`unstable-overflow`)

```
=== gcc -O0 ===
R 12 11 10
=== clang -O3 ===
R 10 11 12
```

| Metric | Result |
|--------|--------|
| Differential detected | YES |
| Classification | `PROGRAM_UB` (unsequenced side effects / EvalOrder) |
| Mock/stub rate | `MOCK_PCT=0` |
| Unstable binary present | YES |
| libtiff binary present | YES |

Bounded AFL++ differential fuzz executed (`T1_FUZZ=RAN`); session terminated by operator after cycle 7 (expected for smoke window).

## Phase 2 — Co-tenancy Isolation & Safety Conformance

| Check | Result |
|-------|--------|
| No PM2 mutation in wrappers | PASS |
| No nginx/mongo mutation commands | PASS |
| No `/opt` path escape to co-resident apps | PASS |
| No obvious secrets in owned tree | PASS |
| systemd resource caps visible | PASS (`MemoryMax=2684354560`) |
| Wipe refused without explicit confirm | PASS |
| PM2 guard baseline | PASS (`count=6`, `restarts_sum=131`) |

## Phase 3 — End-to-End Differential Confirmation

Oracle re-run on independent output directory reproduced identical disagreement:

```
=== gcc -O0 ===
R 12 11 10
=== clang -O3 ===
R 10 11 12
```

| Metric | Result |
|--------|--------|
| Triage pipeline | `TRIAGE_OK` → `CLASS=PROGRAM_UB` |
| Ultra confirmation | `ULTRA_PASS=PASS` |
| Ephemeral retention | `KEEP_UNTIL_USER_WIPE=1` |
| Root filesystem avail | 82G on `/` |

## Resource envelope

- `AUTO_WIPE=0`
- `Nice=5`
- `MemoryMax=2.5G` (systemd)

**Conclusion:** All acceptance gates satisfied. Deployment cleared for operational use pending explicit user wipe order only.
