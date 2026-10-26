# cx-vector-bool — measured, still hint

## Status
**hint**. Wall-clock JSONL: [cx-vector-bool.jsonl](cx-vector-bool.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`clang++ -std=c++17 -O2` (Apple clang version 21.0.0 (clang-2100.1.1.101)). Both containers hold 2,000,000 true elements. Before walks the packed bool container. After walks `vector<unsigned char>`. The harness sums the elements across 9 timed rounds after 3 warmups. Checksums matched (18,000,000). After time stayed above 0.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | byte iterator walk | 0.092833 | 2000000 | 1 |
| before | packed bool iterator walk | 1.126333 | 2000000 | 12.133 |

Indexed reads of the same containers were 4.237× (0.393333 / 0.092834 ms, 2000000 ops). `push_back` of 400,000 values into a reserved container was 6.939× (0.721375 / 0.103958 ms). Those two stayed under the bar.

Eight million elements, counted with an allocator on this standard library: the packed container allocated 1,000,000 bytes in 1 allocation; the byte container allocated 8,000,000 bytes in 1 allocation. The packed container is smaller. This hint is the walk, and it is not a reason to pack other bool fields.

## Limits
The scanner flags the type `vector<bool>` (with or without `std::`) on the line it is spelled. It does not know whether the hot use is a walk (about 12×), an index (about 4.2×), or a push (about 6.9×). Keeping the packed container is the right call when the byte saving matters more than the walk.

Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. An index-only use, or a program that needs the smaller layout, can make the byte container the wrong fix. Corpus triage is still required before any default change.
