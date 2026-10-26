# jp-string-plus-in-loop — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. The matcher saw `+=` of a string literal or `String.fromCharCode` and told you to switch to `push` then `join`. That rewrite does not have about a 2× gain on those shapes. The matcher is deleted. The slug is never reused.

## How measured

`examples/bench/evidence_jp005_jp006.js`. Nine rounds after three warm-up runs; median. Both sides build the same string and read its length. Node v24.18.0, V8 13.6.233.17-node.50. JSONL: [jp-string-plus-in-loop.jsonl](jp-string-plus-in-loop.jsonl).

`ratio` is `+=` time / `join` time. About 2 would mean `join` is twice as fast. Under 1 means `join` is slower.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| before | `s += "\n"`, 100 chars × 200 | 0.194 | 20000 | 1.534 |
| after | `push` + `join` | 0.126 | 20000 | 1 |
| before | `s += "\n"`, 22000 chars × 20 | 1.648 | 440000 | 0.598 |
| after | `push` + `join` | 2.756 | 440000 | 1 |
| before | `s += "\n"`, 44000 chars × 10 | 1.459 | 440000 | 0.459 |
| after | `push` + `join` | 3.176 | 440000 | 1 |
| before | `String.fromCharCode`, 22000 × 10 | 0.893 | 220000 | 0.337 |
| after | `push` + `join` | 2.647 | 220000 | 1 |
| before | `String.fromCharCode`, 44000 × 5 | 0.688 | 220000 | 0.197 |
| after | `push` + `join` | 3.494 | 220000 | 1 |
| before | 64-char literal × 700 × 40 | 0.070 | 28000 | 0.310 |
| after | `push` + `join` | 0.226 | 28000 | 1 |
| before | `obj.s += "\n"`, 22000 × 10 | 0.759 | 220000 | 0.418 |
| after | `push` + `join` | 1.816 | 220000 | 1 |
| before | `s += ch` (the matcher did not see this) | 1.178 | 440000 | 0.417 |
| after | `push` + `join` | 2.823 | 440000 | 1 |

The only case where `join` was faster is 100 newlines, at 1.53×, under the gate. At 22000 and 44000 characters, `join` is slower. V8 already builds the string for `+=` in a loop. `push` then `join` also allocates the pointer array.

## Fixtures

Historical bad/good fixtures live under `_removed/fixtures/`. They are not part of the smoke run.
