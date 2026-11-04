# objcperf 规则 ID（slug）

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

## 已重命名 2026-10-27 （墓碑化旧 ID；永不复用）

Default **`--scope all`** (or kit-equivalent). 旧的 `*-in-loop` ID 会误导工具/模型；它们被墓碑化在 `evidence/_removed/` 下。

| 旧 slug | 新 slug |
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

另见 [根目录 rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。
