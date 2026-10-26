# cs-list-add-no-capacity — List.Add without Capacity

**Status:** measured

## Claim

`new List<int>()` then Add N times is about 1.31× `new List<int>(N)` on .NET 10.0.13. An earlier busy-machine pair was about 1.25×. Two later runs on the same host were about 1.72× (0.462 ms vs 0.269 ms, and 0.426 ms vs 0.248 ms); the no-capacity samples spread from about 0.30 ms to 0.90 ms, so those runs do not replace the row below. The old ~13× figure is not this run. The rule stays off.

## How measured

- Harness: `examples/bench/EvidenceCsBench` (`dotnet run -c Release`)
- N=200000

- Raw lines: [`cs-list-add-no-capacity.jsonl`](cs-list-add-no-capacity.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 UTC (linux x64, load 0.58) |
| dotnet | **10.0.13** |
| Median before (`list_add_nocap`) | 0.4057 ms |
| Median after (`list_capacity`) | 0.3101 ms |
| **ratio before/after** | **~1.31×** |

## Lint mapping

`csharpperf-lint` cs-list-add-no-capacity: keep default severity.

## Limits

- Default stays **off** (G3).
