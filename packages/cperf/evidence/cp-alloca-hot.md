# cp-alloca-hot — measured stack growth, still hint

## Status

**hint**. Wall-clock JSONL: [cp-alloca-hot.jsonl](cp-alloca-hot.jsonl). That file is the timed companion. The passing measurement is the stack cover below. Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug. A VLA in the loop body is not matched.

## Measurement

clang 21.0.0, `-std=c11 -O2`. Both sides write two bytes per iteration and keep a volatile accumulator. The before side calls `alloca(64)` on every pass and retains the first and last block addresses, so the blocks stay live until the function returns. Cover is the distance from the lowest byte to one past the highest.

| role | case | stack_bytes | ops |
|------|------|------------:|----:|
| after | one buffer | 64 | 20000 |
| before | `alloca` each iteration | 1280000 | 20000 |

Wall clock for the same touch, 80 calls of that 20000-iteration loop. The after time is not zero. The ratio is about 1.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `one_buffer` | 0.295 | 1600000 | 1 |
| before | `alloca_each_iter` | 0.293 | 1600000 | 0.993 |

This is not a general speedup. The hint exists because each iteration added another 64-byte block. Reusing one buffer did not make the two-byte touch faster once the stack was already resident.

A VLA of 64 bytes inside a 2000-iteration loop covered 64 bytes. The slot is reused, so that pattern is not matched.

## Unblock

Do not set the default to `error` from this file alone. If every block must stay live until the function returns, one buffer is the wrong rewrite, and the stack still grows. Corpus triage is still required before any default change.
