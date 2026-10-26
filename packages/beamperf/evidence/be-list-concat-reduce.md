# be-list-concat-reduce — list ++ in reduce

**Status:** measured

## Claim

`acc ++ [i]` in a reduce is dramatically slower than cons + `Enum.reverse/1` (~776×) on OTP 29 / Elixir 1.20.4.

## How measured

- Harness: `examples/bench/evidence_be001_be003.exs`
- N=8000; warm=3; median of 9; `:erlang.monotonic_time(:nanosecond)`

- Raw lines: [`be-list-concat-reduce.jsonl`](be-list-concat-reduce.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| otp | **27** |
| elixir | **1.18.3** |
| Median before (`list_plusplus`) | 95.715 ms |
| Median after (`cons_reverse`) | 0.123 ms |
| **ratio before/after** | **~776×** |

## Lint mapping

`beamperf-lint` be-list-concat-reduce: keep package default severity; evidence does not auto-escalate.

## Limits

- Quadratic list growth; real code should prefer cons or `:lists.reverse`.
- Default stays **hint** despite large ratio (no severity escalate this pass).
