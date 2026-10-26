# rs-map-new-in-loop — measured, hint

## Status

**hint**. Wall-clock JSONL: [rs-map-new-in-loop.jsonl](rs-map-new-in-loop.jsonl). Not corpus-triaged. The rule was removed after an older 2.07× pair, then put back: two quiet rustc 1.99.1 runs on linux x64 (load 0.03 and 0.11) were **1.533×** and **1.510×**.

## Measurement

20000 inserts of one key. Before `HashMap::new` each iteration; after clears one map created with `with_capacity(1)`. Both sides read the inserted value.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `map_reused` | 0.392946 | 20000 | 1 |
| before | `map_new_each_iter` | 0.602298 | 20000 | 1.533 |

The second run was 0.374781 ms versus 0.565840 ms (1.510×). Samples on both runs sat in a tight band. Default stays **hint**. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing key set or a cold path can erase the difference.
