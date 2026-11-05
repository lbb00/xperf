# zp-oversized-enum-tag — 不适用（静态大小）

## 状态

**不适用（固定大小）** — 没有 `evidence/zp-oversized-enum-tag.jsonl`。不要自行编造。

## 原因

超大枚举标签是一个 **ABI / 大小** 问题的迹象（`@sizeOf`）。实时时钟是错误的门。

## 为什么没有 JSONL

静态大小比较是证据；微基准测试就是表演。

## 解阻条件

可选：如果对教学有用，可在 md 中在 `@sizeOf` 前/后记录 — JSONL 速度限制仍然没有。规则保持**关闭**。
