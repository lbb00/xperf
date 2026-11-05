# nm-seq-no-capacity — 用 add 培养的空序列

## 状态

**在 Nim 2.2.12 `-d:release` 上测量**。默认严重性保持为 **提示**。

## 运行时

| 字段 | 值 |
|-------|--------|
| When | 2026-10-23 UTC |
| 在 `empty_add` 之前 | 0.699 毫秒 (操作=200000) |
| 在 `newSeqOfCap` 之后 | 0.493 毫秒 |
| **前后比例** | **~1.42×** |

线束：`examples/bench/evidence_nm.nim`。配对夹具保持在`nimperf-lint/fixtures/`下。
