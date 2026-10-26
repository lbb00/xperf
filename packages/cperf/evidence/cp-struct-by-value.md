# cp-struct-by-value — measured, still hint

## Status

**hint**. Wall-clock JSONL: [cp-struct-by-value.jsonl](cp-struct-by-value.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

clang 21.0.0, `-std=c11 -O2`. The callee is in another translation unit. The record is eight `int` fields and `unsigned char pad[480]` (`sizeof` 512). Both sides call the function and add two fields plus the first and last pad bytes into a volatile accumulator. Median of 11.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `pass_pointer` | 0.152 | 128000 | 1 |
| before | `pass_by_value` | 1.864 | 128000 | 12.263 |

A static `noinline` pair in one translation unit, same record and the same 128000 calls, was 0.153 ms versus 0.158 ms (ratio 0.968). The compiler removed the copy. This is not a general speedup.

The scanner fires when a parameter is `struct Name x` with no `*`, the struct is defined earlier in the same file, a lower bound of the members it understands is at least 512 bytes, and there are at least four such fields. That lower bound uses LP64 widths (`int` 4, `long` and pointer 8) and skips nested types, bit-fields, and other members it does not understand, so a large record can be missed. On a repeat, a 320-byte record was 5.848× and a 448-byte record was 6.781×, so those sizes are not matched.

## Unblock

Do not set the default to `error` from this file alone. A same-file static function, a cold call, or a record the size heuristic underestimates can erase the difference. Corpus triage is still required before any default change.
