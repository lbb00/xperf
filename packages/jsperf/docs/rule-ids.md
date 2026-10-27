# jsperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `jp-alloc-in-loop` |
| `jp-console-in-loop` |
| `jp-delete-shape` |
| `jp-delete-array-hole` |
| `jp-map-filter-chain` |
| `jp-regex-ctor-in-loop` |
| `jp-json-in-loop` |
| `jp-dom-query-in-loop` |
| `jp-intl-datetimeformat-in-loop` |
| `jp-readfile-sync-in-loop` |
| `jp-clock-in-loop` |
| `jp-query-all-star` |
| `jp-execjs-in-timer` |
| `jp-clone-per-event` |

## Removed (tombstone; never reuse)

- `jp-string-plus-in-loop` — `push` + `join` was not ~2× on the matched shapes. See `evidence/_removed/`.

See also [root rule-id-map](../../../docs/rule-id-map.md).
