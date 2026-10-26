# Guide-only fixtures (not lint-gated)

Samples under this directory document **guide-first** smells that are **not** registered in `Rule.RULES` and are **not** scanned by `FixtureTest` (`bad/` / `good/` only).

| Sample | Proposed ID | Status |
|--------|-------------|--------|
| `vt-unsafe-threadlocal-pool_bad.java` / `_good.java` (+ `.kt`) | `vt-unsafe-threadlocal-pool` | Guide §10.2 only; high FP on ordinary `ThreadLocal` caches — do not ship until reverse-opt proves low FP |

Do **not** move these into `fixtures/bad/` until a rule exists (or FixtureTest would fail: every `bad/*` must fire its ID).
