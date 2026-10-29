# nimperf evidence policy

## Gate

A rule may be **`error`** only with both `evidence/<RULE>.md` and measured `evidence/<RULE>.jsonl`.

## Current map

As of 2026-10-22.

| Rule | Severity | Evidence | Smell |
|------|----------|----------|-------|
| nm-seq-add-hot | **off** | Nim 2.2.12 ~**8.97×** | seq `.add` in loop (G3 OK-idiom) |
| nm-echo-hot | **off** | Nim 2.2.12 ~**1670×** (after 0.003 ms) | `echo` in loop (G3 CLI) |
| nm-seq-no-capacity | hint | Nim 2.2.12 ~**1.42×** | empty seq + `.add` in size-hinted loop |

No measured JSONL — nm-seq-no-capacity stays **hint**. `nm-string-amp-in-loop` was removed: on Nim 2.2.12 `join` was slower than `&=` (about 0.79×, and an earlier run about 0.69×). See `evidence/_removed/`.
