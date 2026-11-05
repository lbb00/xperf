# nimperf 规则 ID（slug）

Canonical ids are **slugs only**. Numerics from the old map are historical and **not** accepted.

| Slug |
|------|
| `nm-seq-add-hot` |
| `nm-echo-hot` |
| `nm-seq-no-capacity` |

Removed: `nm-string-amp-in-loop` — see `evidence/_removed/`.

另见 [根目录 rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。

## 已重命名 2026-10-27 （墓碑化旧 ID；永不复用）

Default **`--scope all`** (or kit-equivalent). 旧的 `*-in-loop` ID 会误导工具/模型；它们被墓碑化在 `evidence/_removed/` 下。

| 旧 slug | 新 slug |
|----------|----------|
| `nm-echo-in-loop` | `nm-echo-hot` |
| `nm-seq-add-in-loop` | `nm-seq-add-hot` |
