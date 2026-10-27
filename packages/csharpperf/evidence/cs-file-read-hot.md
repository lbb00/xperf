# cs-file-read-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [cs-file-read-hot.jsonl](cs-file-read-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`File.ReadAllText` of one one-byte file, 2000 times, versus reading once. .NET **10.0.13**, linux x64, load 0.07. One `read_once` sample was 1.740 ms; the median is the 0.015–0.026 ms cluster. The earlier .NET 8 pair was about 1560×.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `read_once` | 0.0178 | 2000 | 1 |
| before | `read_each_iter` | 6.0142 | 2000 | 337.876 |

The bench reopens one one-byte file. A path that changes every iteration cannot be hoisted; the measured cost is the open and read. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
