# jp-clock-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [jp-clock-in-loop.jsonl](jp-clock-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`Date.now` and `performance.now`, each compared with one sample outside the loop. `new Date` is not this rule.

Node **v26.12.1**, V8 **14.6.202.34-node.40**, linux x64, load 0.61. Warm 3, median of 9. Harness: `examples/bench/evidence_jp_clock.js`. The earlier Node 24 pair was about 26× / 19×.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `date_now_once` | 0.043 | 100000 | 1 |
| before | `date_now_each` | 2.982 | 100000 | 69.712 |
| after | `perf_now_once` | 0.027 | 100000 | 1 |
| before | `perf_now_each` | 2.980 | 100000 | 110.209 |

`date_now_once` had two slow samples (0.297 ms, 0.125 ms) before the rest sat at 0.029–0.051 ms. The median is in that cluster. Against the slowest sample the each side is still about 10×. `performance.now` samples were tight. After samples once and does not read the clock inside the loop. Code that needs a fresh timestamp every pass has nothing to hoist. Default stays **hint**. This ratio is not a general speedup.

## Matcher

The ratios above are a tight loop that does not wait. A loop that contains `await`, and a `for await` loop, are not reported. Hoist the sample only when that iteration does not need a fresh time. A rate limit or a worker that reads the clock each pass has nothing to move.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
