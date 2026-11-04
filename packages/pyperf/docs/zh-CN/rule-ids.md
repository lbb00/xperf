# pyperf 规则 ID（slug）

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `pp-str-plus-hot` |
| `pp-list-plus-rebind` |
| `pp-print-hot` |
| `pp-json-hot` |
| `pp-deepcopy-hot` |
| `pp-open-hot` |

## 已重命名 2026-10-27 （墓碑化旧 ID；永不复用）

Default **`--scope all`** (or kit-equivalent). 旧的 `*-in-loop` ID 会误导工具/模型；它们被墓碑化在 `evidence/_removed/` 下。

| 旧 slug | 新 slug |
|----------|----------|
| `pp-deepcopy-in-loop` | `pp-deepcopy-hot` |
| `pp-json-in-loop` | `pp-json-hot` |
| `pp-open-in-loop` | `pp-open-hot` |
| `pp-print-in-loop` | `pp-print-hot` |
| `pp-str-plus-in-loop` | `pp-str-plus-hot` |

## Removed (tombstone; never reuse)

- `PP004` — see `evidence/_removed/`
- `pp-regex-compile-in-loop` — see `evidence/_removed/`
- `pp-datetime-format-in-loop` — see `evidence/_removed/`

另见 [根目录 rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。
