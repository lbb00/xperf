# objcperf rule ids (slugs)

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `oc-nsstring-append-hot` |
| `oc-nslog-hot` |
| `oc-dateformatter-hot` |
| `oc-json-hot` |
| `oc-regex-hot` |
| `oc-file-read-hot` |
| `oc-clock-hot` |
| `oc-value-for-key-hot` |

## Renamed 2026-10-27 (tombstone old; never reuse)

Default **`--scope all`** (or kit-equivalent). Old `*-in-loop` ids misled tools/models; they are tombstoned under `evidence/_removed/`.

| Old slug | New slug |
|----------|----------|
| `oc-clock-in-loop` | `oc-clock-hot` |
| `oc-dateformatter-in-loop` | `oc-dateformatter-hot` |
| `oc-file-read-in-loop` | `oc-file-read-hot` |
| `oc-json-in-loop` | `oc-json-hot` |
| `oc-nslog-in-loop` | `oc-nslog-hot` |
| `oc-nsstring-append-in-loop` | `oc-nsstring-append-hot` |
| `oc-regex-in-loop` | `oc-regex-hot` |
| `oc-value-for-key-in-loop` | `oc-value-for-key-hot` |

## Removed (tombstone; never reuse)

- `OC001` — see `evidence/_removed/`
- `OC004` — see `evidence/_removed/`

See also [root rule-id-map](../../../docs/rule-id-map.md).
