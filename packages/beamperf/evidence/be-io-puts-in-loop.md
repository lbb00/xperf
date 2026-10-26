# be-io-puts-in-loop — IO.puts in loop

**Status:** measured

## Claim

Per-iteration `IO.puts` (null group leader) is orders of magnitude slower than summing then one `IO.puts` on OTP 29 / Elixir 1.20.4. The after sample is 0.000834 ms, so the ratio sits on the timer floor.

## How measured

- Harness: `examples/bench/evidence_be001_be003.exs`
- N=5000; IO redirected to a null process

- Raw lines: [`be-io-puts-in-loop.jsonl`](be-io-puts-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| otp | **27** |
| elixir | **1.18.3** |
| Median before (`io_puts_in_loop`) | 3.627 ms |
| Median after (`io_once_after`) | 0.000834 ms |
| **ratio before/after** | **~4349×** |

## Lint mapping

`beamperf-lint` be-io-puts-in-loop: keep package default severity; evidence does not auto-escalate.

## Limits

- I/O / message-passing cost; env-dependent.
- Default stays **off**.
