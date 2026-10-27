# nm-seq-add-hot — seq add in loop

## Status

**Measured** on Nim 2.2.12 `-d:release`. Default severity stays **off**.

## Runtime

| Field | Value |
|-------|--------|
| When | 2026-10-23 UTC |
| before `seq_add` | 0.565 ms (ops=200000) |
| after `index_assign` | 0.063 ms |
| **ratio before/after** | **~8.97×** |

Harness: `examples/bench/evidence_nm.nim`. Paired fixtures stay under `nimperf-lint/fixtures/`.
