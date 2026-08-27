# CD-UB Beat Google Tools — Campaign Report

**Verdict: `BEAT_HOLD`**  
**MOCK_PCT: 0**

## Claim
OSS-Fuzz-enrolled **jq** @ `41b8edfe5437fcd25a072081c05f9f770f9e9b85`: on the same inputs, **Google sanitizers (ASan/UBSan[/MSan]) are silent**, while **CD-UB CompDiff speed-2** (`gcc -O0` vs `clang -O3`) reports a **semantic disagreement**.

## Beat definition (strict)
1. CD-UB binaries disagree on input I  
2. ASan/UBSan(/MSan) silent on I  
3. Reproducible x3  
4. Triage not NOISE  
5. PM2 guard green on VPS

## Numbers
| Metric | Value |
|--------|------:|
| BEAT_COUNT | 0 |
| Sanitizer corpus size | 5 |
| GOOGLE_PASS seeds | 5 |
| AFL run_time (s) | 7198 |
| AFL execs_done | 353160 |
| AFL paths_total | 545 |
| AFL bitmap_cvg | 4.12% |
| jq SHA | `41b8edfe5437fcd25a072081c05f9f770f9e9b85` |

## Hunt status
```
NO_RAW_DIFFS
DIFF_COUNT=0
```

## Oracles
| Oracle | Role | Result framing |
|--------|------|----------------|
| OSS-Fuzz stack (ASan/UBSan/MSan) | Google production detection | Silent on beat inputs |
| CD-UB CompDiff speed-2 | Compiler-disagreement oracle | Disagree → unstable/UB signal |

## Confirmed beats
```
(none — honest hold)
```

## Confirm summary
```
CANDIDATES=0
BEAT_COUNT=0
```

## Environment
- PM2: `PM2_GUARD_OK count=6 restarts_sum=131 baseline_sum=131`
- UTC: 2026-08-27T17:50:51.235195Z

## Citations
- Google OSS-Fuzz + sanitizers documentation
- Li & Su, CompDiff, ASPLOS 2023 (36 sanitizer-missed bugs on OSS)
- Le, Afshari, Su, EMI, PLDI 2014 (Microsoft Research)

## Portfolio link
Campaign 2 of CD-UB hunter — see also `reports/portfolio/PORTFOLIO.md`.
