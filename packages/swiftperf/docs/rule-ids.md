# swiftperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `sp-print-in-loop` |
| `sp-array-no-reserve` |
| `sp-dateformatter-in-loop` |
| `sp-json-decode-in-loop` |
| `sp-regex-in-loop` |
| `sp-file-read-in-loop` |
| `sp-clock-in-loop` |
| `sp-value-for-key-in-loop` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Removed

- `sp-string-plus-in-loop` — `reserveCapacity` was slower; see `evidence/_removed/`
- `sp-map-joined-chain` — about 1.2×; see `evidence/_removed/`
- `sp-force-unwrap-in-loop` — same time as `if let`; see `evidence/_removed/`
