# kt-list-add-hot — ArrayList 空与容量

**状态：** 已测量

## 主张

在 N=2e6 个装箱整数时，空 `ArrayList()` + 添加 与 `ArrayList(n)` 测量结果约为 ~**2.1×**。

## 如何测量

- 测试工具：`examples/bench/EvidenceKt.kt` → jar
- kotlinc 2.0.21 / JRE 21

- 原始行: [`kt-list-add-hot.jsonl`](../kt-list-add-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| kotlin | **2.0.21** |
| jre | **21.0.12.1** |
| 前中值 (`list_add_empty`) | 5.303875 毫秒 |
| (`arraylist_capacity`) 之后的中位数 | 3.358458 毫秒 |
| **前后比例** | **~1.58×** |

## 与 lint 的对应

`kotlinperf-lint` kt-list-add-hot：保持默认；仅限 kit-local KT*。

## 限制

- 拳击占主导地位；容量对某些情况有帮助。不是 jvmperf JMH ID。
- 默认保持 **关闭**。
