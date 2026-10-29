# rustperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `rs-alloc-hot` |
| `rs-println-hot` |
| `rs-format-rebind-hot` |
| `rs-collect-vec-hot` |
| `rs-map-new-hot` |
| `rs-regex-new-hot` |
| `rs-file-open-hot` |
| `rs-clock-hot` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `rs-alloc-in-loop` | `rs-alloc-hot` |
| `rs-clock-in-loop` | `rs-clock-hot` |
| `rs-collect-vec-in-loop` | `rs-collect-vec-hot` |
| `rs-file-open-in-loop` | `rs-file-open-hot` |
| `rs-format-rebind-in-loop` | `rs-format-rebind-hot` |
| `rs-println-in-loop` | `rs-println-hot` |
| `rs-regex-new-in-loop` | `rs-regex-new-hot` |
| `rs-map-new-hot` | `rs-map-new-hot` |

## Removed

- `rs-string-plus-in-loop` — large fill about 1.00×; see `evidence/_removed/`
- `rs-vec-no-capacity` — large fill about 1.00× and about 1.05× bytes; see `evidence/_removed/`
