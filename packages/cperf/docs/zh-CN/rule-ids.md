# cperf 规则 ID（简写）

规范 ID 仅为 **slug**。旧地图中的数字是历史性的，**不**被接受。

| Slug |
|------|
| `cp-alloc-hot` |
| `cp-realloc-grow-one` |
| `cp-printf-hot` |
| `cp-strlen-in-cond` |
| `cp-strcat-hot` |
| `cp-sprintf-hot` |
| `cp-fopen-hot` |
| `cp-gettime-hot` |
| `cp-wide-bool-flags` |
| `cp-regex-hot` |
| `cp-alloca-hot` |
| `cp-struct-by-value` |

另请参见 [root rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。

## 重命名 2026-10-27（旧墓碑；永不重复使用）

默认 **`--scope all`**（或相应的工具包选项）。旧的 `*-in-loop` ID 会误导工具/模型；它们已在 `evidence/_removed/` 下作废。

| 旧别名 | 新别名 |
|----------|----------|
| `cp-alloc-in-loop` | `cp-alloc-hot` |
| `cp-alloca-in-loop` | `cp-alloca-hot` |
| `cp-fopen-in-loop` | `cp-fopen-hot` |
| `cp-gettime-in-loop` | `cp-gettime-hot` |
| `cp-printf-in-loop` | `cp-printf-hot` |
| `cp-regex-in-loop` | `cp-regex-hot` |
| `cp-sprintf-in-loop` | `cp-sprintf-hot` |
| `cp-strcat-in-loop` | `cp-strcat-hot` |
