# cs-string-plus-hot — 循环中的 string +=

**状态：** 已测量

## 主张

在循环中使用不可变的 `string +=` 比使用 `StringBuilder` 对于 N=30000 慢得多。

## 如何测量

- 测试工具：EvidenceCsBench
- 样本量=30000

- 原始行: [`cs-string-plus-hot.jsonl`](../cs-string-plus-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| dotnet | **8.0.32** |
| `string_plus_equals` 之前的中位数 | 226.0176 毫秒 |
| (`stringbuilder`) 后的中位数 | 0.0885 毫秒 |
| **压缩前/后比例** | **~2554×** |

## 与 lint 的对应

`csharpperf-lint` cs-string-plus-hot：保持默认严重性。

## 限制

- 默认保持**关闭**。大比例是无I/O的CPU/分配。
