# arktsperf 规则 ID（别名）

规范 ID 仅为 **slug**。旧地图中的数字是历史性的，**不**被接受。

| Slug |
|------|
| `at-alloc-hot` |
| `at-console-hot` |
| `at-includes-hot` |
| `at-json-hot` |

另请参见 [root rule-id-map](../../../../docs/zh-CN/rule-id-map.md)。

## 重命名 2026-10-27（旧墓碑；永不重复使用）

默认 **`--scope all`**（或相应的工具包选项）。旧的 `*-in-loop` ID 会误导工具/模型；它们已在 `evidence/_removed/` 下作废。

| 旧别名 | 新别名 |
|----------|----------|
| `在循环中分配` | `热分配` |
| `在循环中使用控制台` | `控制台热加载` |
| `在循环中包含` | `热门包含` |
| `at-json-in-loop` | `at-json-hot` |

## 已移除

- `at-object-delete` — 节点代理约 1.01×；见 `evidence/_removed/`
