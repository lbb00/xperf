# zp-catch-unreachable-alloc — 不适用（正确性）

## 状态

**不适用（正确性）** — 没有 `evidence/zp-catch-unreachable-alloc.jsonl`。不要编造一个。

## 原因

`catch unreachable` 在分配时是 **OOM 下的未定义行为**，而不是吞吐量优化。

## 为什么没有 JSONL

正确性/安全性，而不是速度。

## 解阻条件

对于速度门没有。该规则当前**已关闭**，因此 CLI 不会报告它。
