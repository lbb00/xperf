# Kotlin 性能指南（v0）

以 Kotlin 为主的集合 / 字符串 / I/O 核对清单。若要看有测量的 JVM 证据（JMH/JOL），见同级 **jvmperf**。

> **范围：JVM 上的 Kotlin 1.9+。** 本 kit **不**替代 [jvmperf](../../../jvmperf/)。不要在此编造 JMH 比值——请链接或重测。

## 如何阅读

1. 先**测量**（经 jvmperf 的 JMH，或简单墙钟计时）。
2. 把每一章当核对清单，不是强制重写令。
3. 紧密循环里的协程 `launch` 常常是正确性/负载 smell——重写前先画像。

## 目录

- [如何阅读](#如何阅读)
- [1. 集合](#1-集合)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [Lint 对照](#lint-对照)
## 1. 集合

已知大小时优先 `ArrayList(n)` / 带容量的 `MutableList`。能复用缓冲区时，避免每次迭代新建 list。交叉链接：jvmperf 的 `jp-unpresized-collection` / `jp-collection-chain` 覆盖有测量的集合 smell。
## 2. 字符串与热 I/O

循环里的 `s += x` 是经典 builder 场景（`StringBuilder` / `buildString`）。不要把 `println` 放进紧密循环。有测量的字符串拼接见 jvmperf `jp-string-concat-hot`。
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| kt-list-add-hot | 循环内 list 分配 / add 增长 | off |
| kt-string-plus-hot | 循环内字符串 `+=` | off |
| kt-println-hot | 循环内 `println` | off |

仅在有 `evidence/<rule>.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。有测量的 JVM 主张见：[jvmperf](../../../jvmperf/)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
- [jvmperf](../../../jvmperf/)
