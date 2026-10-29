# rubyperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `rb-string-plus-hot` |
| `rb-array-plus-rebind` |
| `rb-puts-hot` |
| `rb-regexp-new-hot` |
| `rb-json-hot` |
| `rb-file-read-hot` |

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `rb-file-read-in-loop` | `rb-file-read-hot` |
| `rb-json-in-loop` | `rb-json-hot` |
| `rb-puts-in-loop` | `rb-puts-hot` |
| `rb-regexp-new-in-loop` | `rb-regexp-new-hot` |
| `rb-string-plus-in-loop` | `rb-string-plus-hot` |

## Removed (tombstone; never reuse)

- `rb-date-parse-in-loop` — see `evidence/_removed/`
- `rb-hash-merge-in-loop` — see `evidence/_removed/`

See also [root rule-id-map](../../../docs/rule-id-map.md).
