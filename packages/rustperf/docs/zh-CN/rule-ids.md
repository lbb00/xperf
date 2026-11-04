# rustperf 规则 ID（slug）

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `rs-alloc-hot` |
| `rs-println-hot` |
| `rs-format-rebind-hot` |
| `rs-collect-vec-hot` |
| `rs-map-new-hot` |
| `rs-regex-new-hot` |
| `rs-file-open-hot` |
| `rs-clock-hot` |

另见 [根目录 rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。

## 已重命名 2026-10-27 （墓碑化旧 ID；永不复用）

Default **`--scope all`** (or kit-equivalent). 旧的 `*-in-loop` ID 会误导工具/模型；它们被墓碑化在 `evidence/_removed/` 下。

| 旧 slug | 新 slug |
|----------|----------|
| `rs-alloc-in-loop` | `rs-alloc-hot` |
| `rs-clock-in-loop` | `rs-clock-hot` |
| `rs-collect-vec-in-loop` | `rs-collect-vec-hot` |
| `rs-file-open-in-loop` | `rs-file-open-hot` |
| `rs-format-rebind-in-loop` | `rs-format-rebind-hot` |
| `rs-println-in-loop` | `rs-println-hot` |
| `rs-regex-new-in-loop` | `rs-regex-new-hot` |
| `rs-map-new-hot` | `rs-map-new-hot` |

## Removed

- `rs-string-plus-in-loop` — large fill about 1.00×; see `evidence/_removed/`
- `rs-vec-no-capacity` — large fill about 1.00× and about 1.05× bytes; see `evidence/_removed/`
