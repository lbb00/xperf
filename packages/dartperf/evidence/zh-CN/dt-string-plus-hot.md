# dt-string-plus-hot — 循环中的字符串 +

**状态：** 已测量

## 主张

`s = s + i.toString()` 比 `StringBuffer` 慢得多（约慢 208 倍），在 Dart 3.13.7 中，N=30000 时。

## 如何测量

- 安全带：evidence_dt.dart

- 原始行: [`dt-string-plus-hot.jsonl`](../dt-string-plus-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| dart | **3.13.6** |
| `string_plus` 之前的中位数 | 95.331 毫秒 |
| (`string_buffer`) 之后的中位数 | 0.458 毫秒 |
| **前/后比例** | **~208×** |

## 与 lint 的对应

`dartperf-lint` dt-string-plus-hot：保持默认严重性。

## 限制

- 默认保持**关闭**。
