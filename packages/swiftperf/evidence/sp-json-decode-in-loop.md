# sp-json-decode-in-loop — measured, still hint

## Status

**hint**. Wall-clock JSONL: [sp-json-decode-in-loop.jsonl](sp-json-decode-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

20000 decodes of one fixed JSON object. After decodes once and rereads the field. A changing payload cannot use this after shape.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `decode_once` | 0.011086 | 20000 | 1 |
| before | `decode_each_iter` | 21.706939 | 20000 | 1957.968 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
