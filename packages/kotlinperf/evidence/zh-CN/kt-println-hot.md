# kt-println-hot — 循环中的 println

**状态：** 已测量

## 主张

每次迭代将 `println` 输出到 `/dev/null` 比安静循环加一次 `println` 慢得多（在 Kotlin 2.4.21 / JDK 27 上大约慢 270 倍）。

## 如何测量

- Harness: EvidenceKt.kt
- N=20000

- 原始行: [`kt-println-hot.jsonl`](../kt-println-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| kotlin | **2.0.21** |
| jre | **21.0.12.1** |
| 循环内打印前的中位数 (`println_in_loop`) | 8.620792 毫秒 |
| (`println_once`) 后的中位数 | 0.031875 毫秒 |
| **前/后比例** | **~270×** |

## 与 lint 的对应

`kotlinperf-lint` kt-println-hot：保持默认；仅限 kit-local KT*。

## 限制

- 默认保持**关闭**。
