# pyperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `pp-str-plus-hot` |
| `pp-list-plus-rebind` |
| `pp-print-hot` |
| `pp-json-hot` |
| `pp-deepcopy-hot` |
| `pp-open-hot` |

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `pp-deepcopy-in-loop` | `pp-deepcopy-hot` |
| `pp-json-in-loop` | `pp-json-hot` |
| `pp-open-in-loop` | `pp-open-hot` |
| `pp-print-in-loop` | `pp-print-hot` |
| `pp-str-plus-in-loop` | `pp-str-plus-hot` |

## Removed (tombstone; never reuse)

- `PP004` — see `evidence/_removed/`
- `pp-regex-compile-in-loop` — see `evidence/_removed/`
- `pp-datetime-format-in-loop` — see `evidence/_removed/`

See also [root rule-id-map](../../../docs/rule-id-map.md).
