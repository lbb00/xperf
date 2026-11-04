# luaperf 证据政策

## 门槛

一条规则只有在 `packages/luaperf/evidence/` 下两者都存在时，才可以被视为 **`error`**：

1. `<RULE>.md` — 声明，如何测量，工具链版本，限制
2. `<RULE>.jsonl` — ≥1 条前/后行，包含 `rule`、`case`、`median_ms`、`ops`、`ratio`、`ts`

否则规则保持 **`hint`**。

## 当前映射

截至2026年10月22日。

| 规则 | 严重性 | 证据 | 异味 |
|------|----------|----------|-------|
| lu-table-insert-hot | 关闭 | 已测量（`lu-table-insert-hot.md` + `lu-table-insert-hot.jsonl`）；保持关闭 | 在循环中使用 table.insert 插入无大小或不断增长的表 |
| lu-string-concat-hot | **错误** | 是 (`lu-string-concat-hot.md` + `lu-string-concat-hot.jsonl`) | 循环中的字符串..连接 |
| lu-print-hot | 提示 | 是 (`lu-print-hot.md` + `lu-print-hot.jsonl`) | 循环打印 |

lu-string-concat-hot 在 Lua 5.4.7 上的 G4 微基准测试后升级（固定形状的数字约 6.6×；固定 32 字节块约 117×；小 N 约 1×）。lu-table-insert-hot 保持 `off`（G3 OK-idiom）。lu-print-hot 有 G4 证据（在 Lua 5.4.7 上 print/quiet 到 `/dev/null` 约 85×），但仍保持 **hint** —— 依赖 I/O 接收器，JP002/CP003 风格（调试/CLI 打印器常用；仅缓冲约 2×）。
