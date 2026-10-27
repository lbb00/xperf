# cperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `cp-alloc-hot` |
| `cp-realloc-grow-one` |
| `cp-printf-hot` |
| `cp-strlen-in-cond` |
| `cp-strcat-hot` |
| `cp-sprintf-hot` |
| `cp-fopen-hot` |
| `cp-gettime-hot` |
| `cp-wide-bool-flags` |
| `cp-regex-hot` |
| `cp-alloca-hot` |
| `cp-struct-by-value` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `cp-alloc-in-loop` | `cp-alloc-hot` |
| `cp-alloca-in-loop` | `cp-alloca-hot` |
| `cp-fopen-in-loop` | `cp-fopen-hot` |
| `cp-gettime-in-loop` | `cp-gettime-hot` |
| `cp-printf-in-loop` | `cp-printf-hot` |
| `cp-regex-in-loop` | `cp-regex-hot` |
| `cp-sprintf-in-loop` | `cp-sprintf-hot` |
| `cp-strcat-in-loop` | `cp-strcat-hot` |
