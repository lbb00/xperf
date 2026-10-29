# kotlinperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `kt-list-add-hot` |
| `kt-string-plus-hot` |
| `kt-println-hot` |

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `kt-list-add-in-loop` | `kt-list-add-hot` |
| `kt-println-in-loop` | `kt-println-hot` |
| `kt-string-plus-in-loop` | `kt-string-plus-hot` |

## Removed (tombstone; never reuse)

- `KT004` — see `evidence/_removed/`

See also [root rule-id-map](../../../docs/rule-id-map.md).
