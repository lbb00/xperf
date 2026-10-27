# rs-clock-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [rs-clock-hot.jsonl](rs-clock-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`Instant::now` every iteration versus one sample. rustc **1.99.1**, `-C opt-level=3`, linux x64, load 0.23. The earlier 438× pair had an after of 0.008 ms. This rerun keeps the loop with `black_box`. One once sample was 0.205 ms; the rest sat at 0.137–0.145 ms.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `sample_once` | 0.137 | 100000 | 1 |
| before | `sample_each_iter` | 2.721 | 100000 | 19.899 |

After samples once and does not read the clock inside the loop. Code that needs a fresh timestamp every pass has nothing to hoist. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
