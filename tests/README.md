# CD-UB Hunter — Test Suite

Engineering verification for the Contabo deployment wrapper. Upstream CompDiff/AFL++ carry their own upstream test harnesses under `vendor/CompDiff/` (not committed).

| Artifact | Purpose |
|----------|---------|
| [TEST_PLAN.md](TEST_PLAN.md) | Formal phase matrix and acceptance criteria |
| [run-suite.sh](run-suite.sh) | Orchestrates Phase 1–3 on a deployed host |
| [run-oracle-local.sh](run-oracle-local.sh) | Portable differential oracle (no CompDiff required) |
| [run-safety-audit.sh](run-safety-audit.sh) | Phase 2 isolation conformance |
| [evidence/](evidence/) | Production run artifacts (real Contabo verification) |

**Maintainer:** abdullah
