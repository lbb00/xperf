# zperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `zp-alloc-hot` |
| `zp-append-without-reserve` |
| `zp-page-allocator-small` |
| `zp-debug-allocator` |
| `zp-large-struct-by-value` |
| `zp-print-hot` |
| `zp-unbuffered-io` |
| `zp-missing-free` |
| `zp-broad-runtime-safety` |
| `zp-packable-bools` |
| `zp-usize-index-field` |
| `zp-aos-single-field` |
| `zp-catch-unreachable-alloc` |
| `zp-oversized-enum-tag` |
| `zp-optional-scalar-field` |
| `zp-bool-array` |
| `zp-static-string-map` |
| `zp-runtime-div-hot` |
| `zp-queue-ordered-remove` |
| `zp-shift-on-read` |
| `zp-per-packet-alloc` |
| `zp-invariant-float-div` |
| `zp-map-put-without-ensure` |
| `zp-catch-unreachable-io` |
| `zp-arena-reset-free-all` |
| `zp-create-destroy-hot` |
| `zp-fixed-size-alloc-hot` |
| `zp-open-file-hot` |
| `zp-clock-hot` |
| `zp-json-hot` |
| `zp-alloc-print-hot` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `zp-alloc-in-loop` | `zp-alloc-hot` |
| `zp-alloc-print-in-loop` | `zp-alloc-print-hot` |
| `zp-clock-in-loop` | `zp-clock-hot` |
| `zp-create-destroy-in-loop` | `zp-create-destroy-hot` |
| `zp-fixed-size-alloc-in-loop` | `zp-fixed-size-alloc-hot` |
| `zp-json-in-loop` | `zp-json-hot` |
| `zp-open-file-in-loop` | `zp-open-file-hot` |
| `zp-print-in-loop` | `zp-print-hot` |
| `zp-runtime-div-in-loop` | `zp-runtime-div-hot` |

## Removed

- `zp-extern-struct-padding` — walk about 1.21×, 24 bytes versus 16; see `evidence/_removed/`
