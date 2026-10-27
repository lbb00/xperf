# be-enum-map-filter-chain — Enum.map |> Enum.filter chain

**Status:** measured

## Claim

Chaining `Enum.map/2` then `Enum.filter/2` (or `Enum.reject/2`) allocates an intermediate list and is slower than a single `Enum.reduce` that maps+filters in one pass (~6.93× and ~6.18×) on OTP 29 / Elixir 1.20.4 for N≈2e5 integers.

## How measured

- Harness: `packages/beamperf/examples/bench/evidence_be004_be005.exs`
- Timing: same as be-map-merge-hot; N=200000 ints spanning negatives and positives
- Pair A: `map(*2) |> filter(>0)` vs one-pass reduce + reverse (matches good `one_pass`)
- Pair B: `map(+1) |> reject(==0)` vs one-pass reduce + reverse
- Raw lines: [`be-enum-map-filter-chain.jsonl`](be-enum-map-filter-chain.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| Elixir | **1.18.3** |
| OTP | **27** |
| Median before (`map_filter_chain`) | 4.546 ms |
| Median after (`one_pass_reduce`) | 0.656 ms |
| **ratio before/after** | **~6.93×** |
| Median before (`map_reject_chain`) | 5.498 ms |
| Median after (`one_pass_reject`) | 0.890 ms |
| **ratio before/after** | **~6.18×** |

## Lint mapping

`beamperf-lint` be-enum-map-filter-chain fires on `Enum.map` piped into `Enum.filter` / `Enum.reject`. Severity stays **hint** (~4.5×; no escalate).

## Limits

- Microbench of pure integer transforms; real pipelines may prefer clarity or Stream.
- `Enum` is eager — Stream would change the story.
- One-pass reduce builds reversed then reverses; other one-pass shapes (comprehension) may differ slightly.
