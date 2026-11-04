# rubyperf 规则 ID（slug）

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `rb-string-plus-hot` |
| `rb-array-plus-rebind` |
| `rb-puts-hot` |
| `rb-regexp-new-hot` |
| `rb-json-hot` |
| `rb-file-read-hot` |

## 已重命名 2026-10-27 （墓碑化旧 ID；永不复用）

Default **`--scope all`** (or kit-equivalent). 旧的 `*-in-loop` ID 会误导工具/模型；它们被墓碑化在 `evidence/_removed/` 下。

| 旧 slug | 新 slug |
|----------|----------|
| `rb-file-read-in-loop` | `rb-file-read-hot` |
| `rb-json-in-loop` | `rb-json-hot` |
| `rb-puts-in-loop` | `rb-puts-hot` |
| `rb-regexp-new-in-loop` | `rb-regexp-new-hot` |
| `rb-string-plus-in-loop` | `rb-string-plus-hot` |

## Removed (tombstone; never reuse)

- `rb-date-parse-in-loop` — see `evidence/_removed/`
- `rb-hash-merge-in-loop` — see `evidence/_removed/`

另见 [根目录 rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。
