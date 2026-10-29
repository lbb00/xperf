# nm-echo-hot — echo in loop

## Status

**Measured** on Nim 2.2.12 `-d:release`, stdout pointed at `/dev/null`. The after sample is 0.003 ms, so the ratio sits on the timer floor. Default severity stays **off**.

## Runtime

| Field | Value |
|-------|--------|
| When | 2026-10-23 UTC |
| before `echo_in_loop` | 5.011 ms (ops=10000) |
| after `echo_once` | 0.003 ms |
| **ratio before/after** | **~1670×** |

Harness: `examples/bench/evidence_nm.nim`. Paired fixtures stay under `nimperf-lint/fixtures/`.
