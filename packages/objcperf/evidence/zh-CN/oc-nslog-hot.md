# oc-nslog-hot — 循环中的 fprintf/NSLog 类似功能

**状态:** 已测量（gnustep 代理）

## 主张

每次迭代将 `fprintf(stderr,…)` 输出到 `/dev/null` 与只执行一次大约 ~**191×**（作为 NSLog 噪音的代理）。

## 如何测量

- 工具：`packages/objcperf/examples/bench/evidence_oc.m`
- N=10000
- 原始行：[`oc-nslog-hot.jsonl`](../oc-nslog-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| runtime | **gnustep** |
| 循环前中位数 (`fprintf_in_loop`) | ~0.6143 毫秒 |
| (`log_once`) 后的中位数 | ~0.003217 毫秒 |
| **前/后比率** | **~191×** |

## 与 lint 的对应

`objcperf-lint` oc-nslog-hot：默认保持 **`关闭`**。

## 限制

- 不是真正的 NSLog；I/O 代理。默认保持**关闭**。
