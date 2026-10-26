# nm-seq-no-capacity — empty seq grown with add

## Status

**Measured** on Nim 2.2.12 `-d:release`. Default severity stays **hint**.

## Runtime

| Field | Value |
|-------|--------|
| When | 2026-10-23 UTC |
| before `empty_add` | 0.699 ms (ops=200000) |
| after `newSeqOfCap` | 0.493 ms |
| **ratio before/after** | **~1.42×** |

Harness: `examples/bench/evidence_nm.nim`. Paired fixtures stay under `nimperf-lint/fixtures/`.
