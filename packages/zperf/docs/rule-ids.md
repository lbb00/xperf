# zperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `zp-alloc-in-loop` |
| `zp-append-without-reserve` |
| `zp-page-allocator-small` |
| `zp-debug-allocator` |
| `zp-large-struct-by-value` |
| `zp-print-in-loop` |
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
| `zp-runtime-div-in-loop` |
| `zp-queue-ordered-remove` |
| `zp-shift-on-read` |
| `zp-per-packet-alloc` |
| `zp-invariant-float-div` |
| `zp-map-put-without-ensure` |
| `zp-catch-unreachable-io` |
| `zp-arena-reset-free-all` |
| `zp-create-destroy-in-loop` |
| `zp-fixed-size-alloc-in-loop` |
| `zp-open-file-in-loop` |
| `zp-clock-in-loop` |
| `zp-json-in-loop` |
| `zp-alloc-print-in-loop` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Removed

- `zp-extern-struct-padding` — walk about 1.21×, 24 bytes versus 16; see `evidence/_removed/`
