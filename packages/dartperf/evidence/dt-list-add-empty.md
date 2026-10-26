# dt-list-add-empty — empty List + add

**Status:** measured

## Claim

Growable `<int>[]` + `add` is slower than `List.filled` + index writes (~4.40×) on Dart 3.13.7.

## How measured

- Harness: `examples/bench/evidence_dt.dart`
- N=200000

- Raw lines: [`dt-list-add-empty.jsonl`](dt-list-add-empty.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| dart | **3.13.6** |
| Median before (`add_loop_empty`) | 9.505 ms |
| Median after (`list_filled`) | 2.158 ms |
| **ratio before/after** | **~4.40×** |

## Lint mapping

`dartperf-lint` dt-list-add-empty: keep default severity.

## Limits

- Default stays **off**.
