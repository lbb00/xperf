# swiftperf 规则 ID（简写）

规范 ID 仅为 **slug**。旧地图中的数字是历史数据，**不**被接受。

| Slug |
|------|
| `sp-print-hot` |
| `sp-array-no-reserve` |
| `sp-dateformatter-hot` |
| `sp-json-decode-hot` |
| `sp-regex-hot` |
| `sp-文件-读取-热` |
| `sp-clock-hot` |
| `sp-针对键的值-hot` |

另请参见 [root rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。

## 重命名 2026-10-27（旧墓碑；永不重复使用）

默认 **`--scope all`**（或相应的工具包选项）。旧的 `*-in-loop` ID 会误导工具/模型；它们已在 `evidence/_removed/` 下作废。

| 旧别名 | 新别名 |
|----------|----------|
| `sp-clock-in-loop` | `sp-clock-hot` |
| `sp-dateformatter-in-loop` | `sp-dateformatter-hot` |
| `sp-file-read-in-loop` | `sp-file-read-hot` |
| `sp-json-decode-in-loop` | `sp-json-decode-hot` |
| `sp-print-in-loop` | `sp-print-hot` |
| `sp-regex-in-loop` | `sp-regex-hot` |
| `循环中键的sp值` | `键快捷的sp值` |

## 已移除

- `sp-string-plus-in-loop` — `reserveCapacity` 更慢；参见 `evidence/_removed/`
- `sp-map-joined-chain` — 大约 1.2 倍；参见 `evidence/_removed/`
- `sp-force-unwrap-in-loop` — 与 `if let` 同样时间；参见 `evidence/_removed/`
