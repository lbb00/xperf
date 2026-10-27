# phpperf evidence policy

## Gate

A rule may be treated as **`error`** only if both exist under `packages/phpperf/evidence/`:

1. `<RULE>.md` — claim, how measured, toolchain version, limits
2. `<RULE>.jsonl` — ≥1 before/after line with `rule`, `case`, `median_ms`, `ops`, `ratio`, `ts`

Otherwise the rule stays **`hint`**.

## Current map

As of 2026-10-22.

| Rule | Severity | Evidence | Smell |
|------|----------|----------|-------|
| ph-string-dot-hot | off | measured (`ph-string-dot-hot.md` + `ph-string-dot-hot.jsonl`); kept off | string `.=` in loop |
| ph-array-merge-rebind | **error** | yes (`ph-array-merge-rebind.md` + `ph-array-merge-rebind.jsonl`) | `array_merge` rebinding in loop |
| ph-echo-hot | hint | measured (`ph-echo-hot.md` + `ph-echo-hot.jsonl`); kept hint | `echo` / `print` in loop |

ph-array-merge-rebind escalated after G4 microbench on PHP 8.4.26 (fixture-shaped scalar ~1848×; 8-element chunks ~344×; small N ~13×). ph-echo-hot has measured evidence (echo each iteration vs `implode` once, ~4.36×) but stays **hint**. ph-string-dot-hot has measured evidence (~3.29×) but stays `off` (G3: mostly OK-idiom).
