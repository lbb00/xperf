# Kotlin 性能指南（v0）

以 Kotlin 为主的集合、字符串与 I/O 核对清单。若要看有测量的 JVM 证据（JMH/JOL），见同级 [jvmperf](../../../jvmperf/)。

> **范围：Kotlin 1.9+（JVM）。** 本 kit 不替代 [jvmperf](../../../jvmperf/)。这里不编造 JMH 比值——请链接或自行重测。
> 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（经 jvmperf 的 JMH，或简单墙钟计时）。各章是核对清单，不是强制重写令。

## 目录

- [1. 集合](#1-集合)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [Lint 对照](#lint-对照)

## 1. 集合

已知大小时优先 `ArrayList(n)` / 带容量的 `MutableList`。能复用缓冲区时，避免每次迭代新建 list。交叉链接：jvmperf 的 `jp-unpresized-collection` / `jp-collection-chain` 覆盖有测量的集合 smell。

Lint: `kt-list-add-hot`（默认 off）
## 2. 字符串与热 I/O

循环里的 `s += x` 是经典 builder 场景（`StringBuilder` / `buildString`）。不要把 `println` 放进紧密循环。有测量的字符串拼接见 jvmperf `jp-string-concat-hot`。

Lint: `kt-string-plus-hot`, `kt-println-hot`（默认 off）
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
