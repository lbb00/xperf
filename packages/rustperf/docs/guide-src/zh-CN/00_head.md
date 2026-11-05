# Rust 性能指南（v0）

少一点分配器噪声，少一点意外的字符串 / 打印停顿。

> **范围：Rust edition 2021+。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（`cargo bench`、`criterion`、`perf`）。LLVM 优化会改变成本——工具链升级后请重测。

## 目录

- [1. 分配与 clone](#1-分配与-clone)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [3. Regex](#3-regex)
- [Lint 对照](#lint-对照)

