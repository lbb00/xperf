# gp-reflect-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [gp-reflect-in-loop.jsonl](gp-reflect-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug. The matcher is `FieldByName`, `MethodByName`, and `reflect.New`. `TypeOf` and `ValueOf` alone are not matched.

## Measurement
Before calls `FieldByName("A")` every iteration. After reads the field. An earlier `TypeOf` microbench was 1.05×. A fair rerun against a saved kind was 1.31× (200000 ops), so that call was dropped. `reflect.New` of an int versus a stack zero was about 41× (100000 ops); that after side does not allocate.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | direct field | 0.061292 | 200000 | 1 |
| before | `FieldByName` every iteration | 6.220041 | 200000 | 101.482 |

go1.27.3, 2026-10-23. Warm 3, median of 9.

Name lookup is the shape that showed a cost. Default stays hint.

## Unblock
Do not set the default to `error` from this file alone. Another input or a cold path can erase the difference. Corpus triage is still required before any default change.
