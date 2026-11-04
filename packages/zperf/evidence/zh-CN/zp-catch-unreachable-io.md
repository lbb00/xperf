# zp-catch-unreachable-io — 不适用（正确性）

## 状态

**不适用（正确性）** — 没有 `evidence/zp-catch-unreachable-io.jsonl`。不要编造一个。

## 原因

`catch unreachable` 在 I/O 上是 **未定义行为 / 出错崩溃**，而不是速度上的优势。

## 为什么没有 JSONL

正确性 / 错误处理，而不是挂钟时间。

## 解阻条件

对于速度门没有。该规则当前**已关闭**，因此 CLI 不会报告它。
