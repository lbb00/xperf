# zp-alloc-print-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [zp-alloc-print-in-loop.jsonl](zp-alloc-print-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`std.fmt.allocPrint` of one runtime `u64`, 20000 times, versus formatting once and reusing the slice. ReleaseFast, median of 9. The formatted byte is mixed into an accumulator so the after loop is not deleted. Before and after produce the same accumulator.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `alloc_print_once` | 0.020375 | 20000 | 1 |
| before | `alloc_print_each_iter` | 1.016875 | 20000 | 49.908 |
| after | `arena_print_once` | 0.020333 | 20000 | 1 |
| before | `arena_print_each_iter` | 0.235416 | 20000 | 11.578 |
| after | `const_print_once` | 0.025834 | 20000 | 1 |
| before | `const_print_each_iter` | 0.362958 | 20000 | 14.050 |

The GPA row is `std.fmt.allocPrint` plus `free` each iteration, against one `allocPrint`. The arena row resets with `retain_capacity` once per timed call, then `allocPrint`s without freeing inside the loop. The constant row is `Allocator.print("hello", .{})`.

Two more runs of the same binary stayed in the same band: GPA 50.795× and 54.930×, arena 11.799× and 11.576×, constant string 14.128× and 15.445×.

`std.fmt.bufPrint` / `std.mem.print` of the same integer was about 4.8× to 5.3×, under the bar, so this rule does not flag buffer formatting. `bufPrint` of a short `{s}:{d}` pair moved between 5.9× and 9.7× across runs, so it is not included either.

A value that changes every iteration cannot be hoisted. The checker only reports a call when the format string and every argument are literals or identifiers that this loop does not assign, capture, or declare. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing argument, a cold path, or another allocator can erase the difference. Corpus triage is still required before any default change.
