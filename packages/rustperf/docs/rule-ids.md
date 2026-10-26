# rustperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `rs-alloc-in-loop` |
| `rs-println-in-loop` |
| `rs-format-rebind-in-loop` |
| `rs-collect-vec-in-loop` |
| `rs-map-new-in-loop` |
| `rs-regex-new-in-loop` |
| `rs-file-open-in-loop` |
| `rs-clock-in-loop` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Removed

- `rs-string-plus-in-loop` — large fill about 1.00×; see `evidence/_removed/`
- `rs-vec-no-capacity` — large fill about 1.00× and about 1.05× bytes; see `evidence/_removed/`
