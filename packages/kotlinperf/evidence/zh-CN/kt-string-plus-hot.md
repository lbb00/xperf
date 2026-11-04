# kt-string-plus-hot — string += 与 buildString

**状态：** 已测量

## 主张

`s +=` 在循环中比 `buildString` 慢得多（N=30000 时约快 521 倍），在 Kotlin 2.4.21 / JDK 27 上测试。

## 如何测量

- 安全带：EvidenceKt.kt

- 原始行: [`kt-string-plus-hot.jsonl`](../kt-string-plus-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| kotlin | **2.0.21** |
| jre | **21.0.12.1** |
| 中位数之前 (`string_plus`) | 93.440375 毫秒 |
| (`buildString`) 后的中位数 | 0.179375 毫秒 |
| **前/后比率** | **~521×** |

## 与 lint 的对应

`kotlinperf-lint` kt-string-plus-hot：保持默认；仅限 kit-local KT*。

## 限制

- 默认保持**关闭**。
