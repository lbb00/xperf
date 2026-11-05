# nm-echo-hot — 循环回声

## 状态

**在** Nim 2.2.12 `-d:release` 上进行测量，标准输出指向 `/dev/null`。之后的样本为 0.003 毫秒，所以比率处于定时器底部。默认严重性保持**关闭**。

## 运行时

| 字段 | 值 |
|-------|--------|
| When | 2026-10-23 UTC |
| 在 `echo_in_loop` 之前 | 5.011 毫秒 (操作=10000) |
| 在 `echo_once` 之后 | 0.003 毫秒 |
| **前/后比例** | **~1670×** |

线束：`examples/bench/evidence_nm.nim`。配对夹具保持在`nimperf-lint/fixtures/`下。
