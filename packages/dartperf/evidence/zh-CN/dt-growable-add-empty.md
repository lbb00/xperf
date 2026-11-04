# dt-growable-add-empty — 空可扩展 + 添加（提示规则）

**状态：** 已测量

## 主张

与 dt-list-add-empty 相同的内核：空可增长 + 添加 与 `List.filled`（约 3.12×）在 Dart 3.13.7 上的比较。

## 如何测量

- Harness: evidence_dt.dart
- N=200000

- 原始行：[`dt-growable-add-empty.jsonl`](../dt-growable-add-empty.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| dart | **3.13.6** |
| 中值之前 (`empty_add`) | 3.820 毫秒 |
| (`list_filled`) 后的中位数 | 1.226 毫秒 |
| **前/后比例** | **~3.12×** |

## 与 lint 的对应

`dartperf-lint` dt-growable-add-empty: 保持默认严重性。

## 限制

- 谦虚；默认保留 **提示**；不升级。
