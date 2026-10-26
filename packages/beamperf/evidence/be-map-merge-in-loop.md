# be-map-merge-in-loop — Map.merge / Keyword.merge in loop

**Status:** measured

## Claim

`Enum.reduce` that calls `Map.merge/2` on each element is slower than updating with `Map.put/3` (~2.30× for a multi-key fold, ~1.77× for a single key) on OTP 29 / Elixir 1.20.4. `Keyword.merge/2` in a reduce is about **2.00×** slower than `Keyword.put/3`.

## How measured

- Harness: `packages/beamperf/examples/bench/evidence_be004_be005.exs`
- Timing: `:erlang.monotonic_time(:nanosecond)`; warm=3; median of 9; GC before each sample
- Pair A: N=5000 maps `%{i => i, :tag => …}` via `Map.merge` vs N=5000 `%{k:, v:}` via `Map.put` (matches good `put_in_loop`)
- Pair B: N=5000 single-key maps — `Map.merge` vs `Map.put` on same shape
- Pair C: N=2000 keyword lists — `Keyword.merge` vs `Keyword.put`
- Raw lines: [`be-map-merge-in-loop.jsonl`](be-map-merge-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| Elixir | **1.18.3** |
| OTP | **27** |
| Median before (`map_merge_reduce`) | 2.099 ms |
| Median after (`map_put_kv`) | 0.912 ms |
| **ratio before/after** | **~2.30×** |
| Median before (`map_merge_single`) | 1.726 ms |
| Median after (`map_put_single`) | 0.973 ms |
| **ratio before/after** | **~1.77×** |
| Median before (`keyword_merge_reduce`) | 2.304 ms |
| Median after (`keyword_put`) | 1.153 ms |
| **ratio before/after** | **~2.00×** |

## Lint mapping

`beamperf-lint` be-map-merge-in-loop fires on `Map.merge` / `Keyword.merge` inside a reduce/loop. Severity stays **hint** — strongest pair ~7× is real but not escalated this pass.

## Limits

- Pair A compares merge-of-multi-key maps to put-of-kv structs (fixture-aligned; not bit-identical work).
- Single-key merge vs put is only ~1.3× — growth cost is small when maps stay tiny.
- Keyword lists are linear; merge cost grows with keyword length.
- Does not measure `:maps.merge/2` NIFs or large persistent structures.
