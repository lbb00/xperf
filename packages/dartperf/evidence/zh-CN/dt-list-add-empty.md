# dt-list-add-empty — 空列表 + 添加

**状态：** 已测量

## 主张

在 Dart 3.13.7 中，可增长的 `<int>[]` + `add` 比 `List.filled` + 索引写入慢（约 4.40 倍）。

## 如何测量

- 工具：`examples/bench/evidence_dt.dart`
- N=200000

- 原始行: [`dt-list-add-empty.jsonl`](../dt-list-add-empty.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| dart | **3.13.6** |
| 中值之前 (`add_loop_empty`) | 9.505 毫秒 |
| (`list_filled`) 后的中位数 | 2.158 毫秒 |
| **前/后比例** | **~4.40×** |

## 与 lint 的对应

`dartperf-lint` dt-list-add-empty：保持默认严重性。

## 限制

- 默认保持**关闭**。
