# nm-seq-add-hot — 循环中添加序列

## 状态

**在 Nim 2.2.12 `-d:release` 上测量**。默认严重性保持 **关闭**。

## 运行时

| 字段 | 值 |
|-------|--------|
| When | 2026-10-23 UTC |
| 在 `seq_add` 之前 | 0.565 毫秒 (操作=200000) |
| 在 `index_assign` 之后 | 0.063 毫秒 |
| **前/后比例** | **~8.97×** |

线束：`examples/bench/evidence_nm.nim`。配对夹具保持在`nimperf-lint/fixtures/`下。
