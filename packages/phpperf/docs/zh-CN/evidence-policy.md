# phpperf 证据政策

## 门槛

一条规则只有在 `packages/phpperf/evidence/` 下两者都存在时，才可以被视为 **`error`**：

1. `<RULE>.md` — 声明，如何测量，工具链版本，限制
2. `<RULE>.jsonl` — ≥1 条前/后行，包含 `rule`、`case`、`median_ms`、`ops`、`ratio`、`ts`

否则规则保持 **`hint``**。

## 当前映射

截至2026年10月22日。

| 规则 | 严重性 | 证据 | 异味 |
|------|----------|----------|-------|
| ph-string-dot-hot | 关闭 | 已测量（`ph-string-dot-hot.md` + `ph-string-dot-hot.jsonl`）；保持关闭 | 循环中的字符串 `.=` |
| ph-array-merge-rebind | **错误** | 是 (`ph-array-merge-rebind.md` + `ph-array-merge-rebind.jsonl`) | 循环中的 `array_merge` 重新绑定 |
| ph-echo-hot | 提示 | 测量（`ph-echo-hot.md` + `ph-echo-hot.jsonl`）；保留提示 | 循环中的 `echo` / `print` |

在 PHP 8.4.26 上进行 G4 微基准测试后，ph-array-merge-rebind 出现了升级（固定形状标量约 1848 倍；8 元素块约 344 倍；小 N 约 13 倍）。ph-echo-hot 有测量证据（每次迭代 echo 与一次 `implode`，约 4.36 倍）但仍保持 **提示**。ph-string-dot-hot 有测量证据（约 3.29 倍）但仍保持 `关闭`（G3：大体上是 OK 习惯用法）。
