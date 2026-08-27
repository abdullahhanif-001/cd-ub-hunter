# Portfolio Elite Evaluation — research basis (no guesses)

## What Google / Microsoft-style reviewers expect
1. **NIST Juliet method** (SAMATE): labeled bad vs good variants → recall + false-positive rate  
   Sources: NIST Juliet 1.3; CompDiff ASPLOS’23; FuZZan ATC’20; ispras/juliet-dynamic.
2. **Sanitizer co-oracle**: ASan / UBSan / MSan as industry baseline; CD-UB must show *complement* not replacement  
   Sources: CompDiff Table 1/3; Google sanitizer docs.
3. **Multi-compiler differential configs** (`gcc -O0` vs `clang -O3`) — EMI / CompDiff lineage  
   Sources: Microsoft Research EMI (PLDI’14); CompDiff ASPLOS’23.
4. **Reproducible artifacts**: compiler versions, SHA256 of binaries/outputs, host facts, no mocks  
   Sources: Alive2 / LLVM continuous validation culture (PLDI’21).
5. **Safety on shared infra**: PM2 guard unchanged (our Contabo constraint).

## This suite
- Curated **ground-truth microbench** (Juliet-method labels: BAD expects disagreement, GOOD expects agreement)
- Classes aligned to CompDiff paper: EvalOrder, IntOverflow-unstable, Uninit-ish, PointerCmp-unstable
- Sanitizer probe: does UBSan/ASan catch the same input?
- Metrics: TP, FN, FP, TN, recall, FPR, sanitizer_missed_but_cdub
- Output: `PORTFOLIO_REPORT.json` + `PORTFOLIO.md` for LinkedIn / resume / interview packet
