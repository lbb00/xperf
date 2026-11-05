# dt-print-hot — 循环打印/写入

**状态：** 已测量

## 主张

每次迭代同步写入 `/dev/null` 比循环结束后一次写入慢得多（在 Dart 3.13.7 上约为 2040 倍）。循环后的样本为 0.004 毫秒，因此比例接近计时器的最小值。

## 如何测量

- 测试工具：evidence_dt.dart
- N=10000

- 原始行：[`dt-print-hot.jsonl`](../dt-print-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| dart | **3.13.6** |
| 中值之前 (`print_in_loop`) | 8.159 毫秒 |
| (`print_once`) 之后的中位数 | 0.004 毫秒 |
| **前/后比例** | **~2040×** |

## 与 lint 的对应

`dartperf-lint` dt-print-hot：保持默认严重性。

## 限制

- `print` 的 I/O 代理；默认保持 **关闭**。
