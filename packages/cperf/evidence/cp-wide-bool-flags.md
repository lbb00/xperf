# cp-wide-bool-flags — measured, still hint

## Status

**hint**. Wall-clock JSONL: [cp-wide-bool-flags.jsonl](cp-wide-bool-flags.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

Copy of 1000000 records. The wide struct is four ints (16 bytes in this build). The packed struct is four unsigned char bit-fields (1 byte in this build). This is a bandwidth microbench of those two layouts, not a claim about every ABI.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `copy_uchar_bitfields` | 0.067000 | 1000000 | 1 |
| before | `copy_four_ints` | 1.277000 | 1000000 | 19.060 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
