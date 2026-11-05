# cppperf 规则 ID（slug）

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `cx-regex-ctor-hot` |
| `cx-endl-hot` |
| `cx-clock-hot` |
| `cx-ifstream-hot` |
| `cx-const-by-value` |
| `cx-vector-bool` |

## 已重命名 2026-10-27 （墓碑化旧 ID；永不复用）

Default **`--scope all`** (or kit-equivalent). 旧的 `*-in-loop` ID 会误导工具/模型；它们被墓碑化在 `evidence/_removed/` 下。

| 旧 slug | 新 slug |
|----------|----------|
| `cx-clock-in-loop` | `cx-clock-hot` |
| `cx-endl-in-loop` | `cx-endl-hot` |
| `cx-ifstream-in-loop` | `cx-ifstream-hot` |
| `cx-regex-ctor-in-loop` | `cx-regex-ctor-hot` |

## Removed

- `cx-string-append-unreserved` — about 1.09× at `-O2`; see `evidence/_removed/`

## Removed (no slug)

- `CX001` — see `evidence/_removed/`
- `CX003` — see `evidence/_removed/`
- `CX004` — see `evidence/_removed/`

另见 [根目录 rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。
