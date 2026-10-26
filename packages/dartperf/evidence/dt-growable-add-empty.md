# dt-growable-add-empty — empty growable + add (hint rule)

**Status:** measured

## Claim

Same kernel as dt-list-add-empty: empty growable + add vs `List.filled` (~3.12×) on Dart 3.13.7.

## How measured

- Harness: evidence_dt.dart
- N=200000

- Raw lines: [`dt-growable-add-empty.jsonl`](dt-growable-add-empty.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| dart | **3.13.6** |
| Median before (`empty_add`) | 3.820 ms |
| Median after (`list_filled`) | 1.226 ms |
| **ratio before/after** | **~3.12×** |

## Lint mapping

`dartperf-lint` dt-growable-add-empty: keep default severity.

## Limits

- Modest; default stays **hint**; no escalate.
