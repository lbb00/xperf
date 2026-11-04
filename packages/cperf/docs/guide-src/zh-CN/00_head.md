# C 性能指南（v0）

少一点无谓分配，少一点意外 I/O 卡顿。

> **范围：C11 / C17。** 文中顺带提到的 C++ 备注仅在同一模式适用时成立（例如循环里的 `new` 仍是分配器开销）。凡声称加速的论断，要么有本地示例、要么有上游来源，要么标为暂定。**语料 lint 计数是启发式 dogfood**，不是基准——它告诉你检查器在哪里开火，而不是能省多少墙钟时间。
>
> 配套：`cperf-lint/` —— 十二条规则的行窗启发式（见 § Lint 对照表）。已在 quickjs、lua、gcc（稀疏）以及 sqlite `src/` 上 dogfood（2026-10-21 Asia/Shanghai）。该次运行未覆盖较晚的 hint 规则；见 [corpus.md](corpus.md)。语料树未 vendored。

## 怎么读

1. 先在真实负载上**测量**（`perf`、cachegrind；ASan 找 bug，不是测速）。
2. 把每一章当成检查清单，而不是强制重写。
3. 当 lint 打在引擎 / 编译器代码上时，先确认调用是调试、代码生成，还是有意的 CLI I/O，再谈「修」。

## 目录

- [0. 范围与方法](#0-范围与方法)
- [1. 分配](#1-分配)
- [2. 热路径 I/O](#2-热路径-io)
- [3. 测量](#3-测量)
- [4. 热路径调用](#4-热路径调用)
- [5. 标志布局](#5-标志布局)
- [Lint 对照表](#lint-对照表)
- [参考](#参考)

---

## 0. 范围与方法

进攻顺序（与共享 XPerf playbook 相同）：

1. **设计 / 批处理** —— 把网络、磁盘、内存、CPU 摊到批次上。
2. **分配形态** —— arena、池、容量倍增（§1）。
3. **热路径 I/O** —— 稳态循环里不要放 `printf` / `fprintf`（§2）。
4. **布局 / 编译器** —— SoA、`restrict`、LTO：先测；错误的 `restrict` 是 UB。
5. **验证** —— 计数器与 sanitizer（§3）。

机器侧论断应简要记录编译器、`-O` 级别和 CPU。`cp-alloc-hot`、`cp-realloc-grow-one` 与 `cp-printf-hot` 在 `evidence/` 下提供 JSONL 微基准（见 [evidence-policy.md](evidence-policy.md)）；`examples/` 下其余示例仍是模式演示（`cc -std=c17 -O2`）。

来源：[XPerf playbook](../../../../docs/zh-CN/playbook.md) · [corpus.md](corpus.md)
