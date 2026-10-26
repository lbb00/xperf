# cx-const-by-value — measured, still hint

## Status
**hint**. Wall-clock JSONL: [cx-const-by-value.jsonl](cx-const-by-value.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`clang++ -std=c++17 -O2` (Apple clang version 21.0.0 (clang-2100.1.1.101)). Parameter cases call a function in another translation unit, so the copy is the one the ABI makes. Each side returns `size + first byte` (or `size + first int`). The harness sums that return across 9 timed rounds after 3 warmups. Checksums matched. After times stayed above 0.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | one `int` in a vector, const reference | 0.148417 | 200000 | 1 |
| before | one `int` in a vector, const by value | 2.471000 | 200000 | 16.649 |
| after | 64-byte string, const reference | 0.039792 | 40000 | 1 |
| before | 64-byte string, const by value | 0.610709 | 40000 | 15.348 |
| after | range-for of 128-byte strings, const reference | 0.016042 | 20000 | 1 |
| before | range-for of 128-byte strings, const by value | 0.329708 | 20000 | 20.553 |
| after | range-for of 64-int vectors, const reference | 0.005708 | 8000 | 1 |
| before | range-for of 64-int vectors, const by value | 0.122083 | 8000 | 21.388 |

Same shape, also above the bar, not repeated in the JSONL: a 23-byte string parameter was 16.728× (1.700666 / 0.101667 ms, 100000 ops), 32 bytes 17.504× (1.423625 / 0.081333 ms, 80000), 256 bytes 22.681× (0.462125 / 0.020375 ms, 20000), 4096 bytes 59.952× (1.206541 / 0.020125 ms, 20000). A 4-int vector was 16.145× (2.396875 / 0.148458 ms, 200000). A 1024-int vector, touching the first element, was 74.110× (1.120916 / 0.015125 ms, 20000).

A same-file 4096-byte touch, with a volatile zero added so the reference loop could not disappear, was 115.971× (1.178958 / 0.010166 ms, 20000). Inlining did not remove that copy.

## Limits
These stayed under the bar. The scanner still flags the spelling, because it cannot see the length or the body:

| case | before_ms | after_ms | ops | ratio |
| --- | ---: | ---: | ---: | ---: |
| 4-character string parameter | 0.303834 | 0.301250 | 300000 | 1.009 |
| empty vector parameter | 0.371000 | 0.303334 | 300000 | 1.223 |
| 64-byte string, sum every byte | 0.356583 | 0.081708 | 20000 | 4.364 |
| 4096-byte string, sum every byte | 0.980375 | 0.767625 | 4000 | 1.277 |
| range-for of 4-character strings | 0.020292 | 0.010625 | 40000 | 1.910 |
| 1024-int vector, sum every element | 0.324125 | 0.151917 | 4000 | 2.134 |

The matcher is one line: `const std::string` / `const std::vector<...>` (and the east-const spelling) whose name is followed by `,` or `)`, plus the same types in a `for (` head before `:`. It misses `const auto`, a name on the next line, a default argument (`=`), and a nested `>>`. A non-const by-value parameter is left alone: on a 4096-byte string that copy was 60.510× (1.235375 / 0.020416 ms, 20000 ops), and it is also how a function takes ownership. A local `const std::string copy = ...` is left alone.

Default stays **hint**. These ratios are not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A short string, an empty vector, or a body that reads every element can erase the difference. Corpus triage is still required before any default change.
