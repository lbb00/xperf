# swiftperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `sp-print-hot` |
| `sp-array-no-reserve` |
| `sp-dateformatter-hot` |
| `sp-json-decode-hot` |
| `sp-regex-hot` |
| `sp-file-read-hot` |
| `sp-clock-hot` |
| `sp-value-for-key-hot` |

See also [root rule-id-map](../../../docs/rule-id-map.md).

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `sp-clock-in-loop` | `sp-clock-hot` |
| `sp-dateformatter-in-loop` | `sp-dateformatter-hot` |
| `sp-file-read-in-loop` | `sp-file-read-hot` |
| `sp-json-decode-in-loop` | `sp-json-decode-hot` |
| `sp-print-in-loop` | `sp-print-hot` |
| `sp-regex-in-loop` | `sp-regex-hot` |
| `sp-value-for-key-in-loop` | `sp-value-for-key-hot` |

## Removed

- `sp-string-plus-in-loop` — `reserveCapacity` was slower; see `evidence/_removed/`
- `sp-map-joined-chain` — about 1.2×; see `evidence/_removed/`
- `sp-force-unwrap-in-loop` — same time as `if let`; see `evidence/_removed/`
