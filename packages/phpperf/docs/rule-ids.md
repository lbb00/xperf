# phpperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `ph-string-dot-hot` |
| `ph-array-merge-rebind` |
| `ph-echo-hot` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `ph-echo-in-loop` | `ph-echo-hot` |
| `ph-string-dot-in-loop` | `ph-string-dot-hot` |
