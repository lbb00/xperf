# arktsperf 证据政策

## 门槛

只有在有 `evidence/<slug>.md` + `.jsonl` **和** 首选 ArkTS/设备运行时基准的情况下，规则才可以被视为 **`error`**。仅使用 **Node 代理** 会保持 **`hint`** / 包默认（在 md 中说明）。

## 当前映射

截至2026年10月22日（B批次）。

| 规则 | 严重性 | 证据 | 问题 |
|------|----------|----------|-------|
| at-alloc-hot | 关闭 | 节点代理 JSONL (~33×) | 循环中的分配类似 |
| 控制台热 | 关闭 | 节点代理 JSONL (~208×) | 循环中的控制台 |
| at-includes-hot | 提示 | 节点代理 JSONL (~29× includes→Set) | 循环中的 indexOf/includes |
| at-json-hot | 提示 | 节点代理 JSONL (~2× JSON) | 循环中的 JSON.parse/stringify |

单靠节点代理不会升级严重性。
