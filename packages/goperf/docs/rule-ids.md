# goperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `gp-make-hot` |
| `gp-string-plus-hot` |
| `gp-fmt-hot` |
| `gp-append-nil-slice` |
| `gp-defer-hot` |
| `gp-regexp-compile-hot` |
| `gp-json-marshal-hot` |
| `gp-reflect-hot` |
| `gp-os-open-hot` |
| `gp-time-now-hot` |

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `gp-defer-in-loop` | `gp-defer-hot` |
| `gp-fmt-in-loop` | `gp-fmt-hot` |
| `gp-json-marshal-in-loop` | `gp-json-marshal-hot` |
| `gp-make-in-loop` | `gp-make-hot` |
| `gp-os-open-in-loop` | `gp-os-open-hot` |
| `gp-reflect-in-loop` | `gp-reflect-hot` |
| `gp-regexp-compile-in-loop` | `gp-regexp-compile-hot` |
| `gp-string-plus-in-loop` | `gp-string-plus-hot` |
| `gp-time-now-in-loop` | `gp-time-now-hot` |

## Removed (tombstone; never reuse)

- `gp-time-parse-in-loop` — see `evidence/_removed/`

See also [root rule-id-map](../../../docs/rule-id-map.md).
