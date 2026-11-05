# cs-console-hot — 循环中的 Console.WriteLine

**状态：** 已测量

## 主张

每次迭代将 `Console.WriteLine` 输出到 `TextWriter.Null` 比安静循环加一次写入要慢（在 .NET 10.0.13 上约慢 17.9 倍）。

## 如何测量

- 安装工具：EvidenceCsBench
- N=20000；控制台重定向到空

- 原始行：[`cs-console-hot.jsonl`](../cs-console-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| dotnet | **8.0.32** |
| 循环内控制台前的中位数 (`console_in_loop`) | 0.2333 毫秒 |
| (`console_once`) 后的中位数 | 0.0130 毫秒 |
| **前后比例** | **~17.95×** |

## 与 lint 的对应

`csharpperf-lint` cs-console-hot：保持默认严重性。

## 限制

- 依赖环境；默认保持 **关闭**。
