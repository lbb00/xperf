# jp-map-filter-chain — measured, still hint

## Status

**hint**. Wall-clock JSONL: [jp-map-filter-chain.jsonl](jp-map-filter-chain.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

`examples/bench/evidence_jp005_jp006.js`. Nine rounds after three warm-up runs; median. Both sides build the result array and sum it. Node v24.18.0, V8 13.6.233.17-node.50.

`ratio` is chain time / one-pass time. The cost grows with the length and with how many passes you make.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| before | 3 rows, filter then map, × 20000 | 0.289 | 60000 | 1.276 |
| after | one pass | 0.226 | 60000 | 1 |
| before | 3 rows, four filters then map, × 20000 | 0.761 | 60000 | 3.460 |
| after | one pass | 0.220 | 60000 | 1 |
| before | 100 rows, filter then map, × 2000 | 0.504 | 200000 | 1.228 |
| after | one pass | 0.410 | 200000 | 1 |
| before | 100 rows, four filters then map, × 2000 | 1.026 | 200000 | 2.487 |
| after | one pass | 0.413 | 200000 | 1 |
| before | 35000 rows, filter then map, × 20 | 8.728 | 700000 | 4.598 |
| after | one pass | 1.898 | 700000 | 1 |
| before | 35000 rows, four filters then map, × 20 | 12.850 | 700000 | 9.841 |
| after | one pass | 1.306 | 700000 | 1 |

A 3-row `filter` then `map` is 1.28×, under the about-2× bar. Four passes on 3 rows is 3.46×, and 20000 calls still finish in 0.76 ms. On 35000 rows one pass is about 4.6× (one filter) and about 9.8× (four filters). Those are different costs. The hint says so. It does not say every chain must be rewritten.

The matcher strips `//` comments and block comments before it looks. It does not know the array length, and it does not require a loop. A generated `gen-*` file is still skipped.

## Unblock

Do not set the default to `error` from this file alone. A short array, a cold path, or another engine can erase the difference. Corpus triage is still required before any default change.
