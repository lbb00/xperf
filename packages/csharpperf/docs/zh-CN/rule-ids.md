# csharpperf 规则 ID（别名）

规范 ID 仅为 **slug**。旧地图中的数字是历史性的，**不**被接受。

| Slug |
|------|
| `cs-list-add-no-capacity` |
| `cs-string-plus-hot` |
| `cs-console-hot` |
| `cs-regex-hot` |
| `cs-linq-materialize-hot` |
| `cs-format-hot` |
| `cs-json-hot` |
| `cs-file-read-hot` |
| `cs-clock-hot` |
| `按名称热字段` |

另请参见 [root rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。

## 重命名 2026-10-27（旧墓碑；永不重复使用）

默认 **`--scope all`**（或相应的工具包选项）。旧的 `*-in-loop` ID 会误导工具/模型；它们已在 `evidence/_removed/` 下作废。

| 旧别名 | 新别名 |
|----------|----------|
| `cs-clock-in-loop` | `cs-clock-hot` |
| `cs-console-in-loop` | `cs-console-hot` |
| `循环中的按名称字段` | `热门按名称字段` |
| `cs-file-read-in-loop` | `cs-file-read-hot` |
| `cs-循环中格式` | `cs-格式热点` |
| `cs-json-in-loop` | `cs-json-hot` |
| `cs-linq-在循环中实现` | `cs-linq-实现热数据` |
| `cs-regex-in-loop` | `cs-regex-hot` |
| `cs-string-plus-in-loop` | `cs-string-plus-hot` |
