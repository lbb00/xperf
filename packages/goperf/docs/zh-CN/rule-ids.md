# goperf 规则 ID（别名）

规范 ID 仅为 **slug**。旧地图中的数字是历史性的，**不**被接受。

| Slug |
|------|
| `gp-make-hot` |
| `gp-string-plus-hot` |
| `gp-fmt-hot` |
| `gp-append-nil-slice` |
| `gp-defer-hot` |
| `gp-regexp-compile-hot` |
| `gp-json-marshal-hot` |
| `gp-reflect-hot` |
| `gp-os-open-hot` |
| `gp-time-now-hot` |

## 重命名 2026-10-27（旧墓碑；永不重复使用）

默认 **`--scope all`**（或工具包等效选项）。旧的 `*-in-loop` ID 误导了工具/模型；它们已在 `evidence/_removed/` 下作废。

| 旧别名 | 新别名 |
|----------|----------|
| `gp-defer-in-loop` | `gp-defer-hot` |
| `gp-fmt-in-loop` | `gp-fmt-hot` |
| `gp-json-marshal-in-loop` | `gp-json-marshal-hot` |
| `gp-make-in-loop` | `gp-make-hot` |
| `gp-os-open-in-loop` | `gp-os-open-hot` |
| `gp-reflect-in-loop` | `gp-reflect-hot` |
| `gp-regexp-compile-in-loop` | `gp-regexp-compile-hot` |
| `gp-string-plus-in-loop` | `gp-string-plus-hot` |
| `gp-time-now-in-loop` | `gp-time-now-hot` |

## 已移除（墓碑；永不复用）

- `gp-time-parse-in-loop` — 见 `evidence/_removed/`

另请参见 [root rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。
