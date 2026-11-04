# JavaScript 性能指南（v0）

稳定的 shape、更少的每轮分配——另有一章讲工具链 / 冷启动。

> **焦点：现代 Node 与 V8 IC / GC。** QuickJS 与小程序类嵌入有专章（§3）——避免只在有 DOM 或完整浏览器 profiler 时才说得通的建议。**§4 深化 V8**（map、elements kind、deopt、Ignition→Maglev/Turbofan）；**不**适用于 §3 运行时。**§5** 覆盖**启动与工具链**（模块解析、急切图、barrel），依据 Marvin Hagemeister 的生态系列——与 jp-* lint 规则正交。
>
> 凡声称加速的论断，要么有本地示例、要么有上游来源，要么标为暂定。**语料 lint 计数是启发式 dogfood**，不是基准。§4.6 只引用单机微基准中位数。§5 引用 Marvin 的**方法**（URL）；他的计时请在本地重测。
>
> 配套：`jsperf-lint/` —— jp-* 规则，见 [Lint 对照表](#lint-对照表)（行窗；非完整解析器）。已在 Node `lib/`、Preact `src/`、quickjs `*.js`（跳过测试）以及 TypeScript `packages/typescript/src` 上 dogfood（2026-10-21 Asia/Shanghai）。见 [corpus.md](corpus.md)。启动 / FS 成本对 jp-* 规则是**带外**的——见 §5。

## 怎么读

1. 先做 profile（`node --prof`、`node --cpu-prof` + speedscope、Chrome Performance、clinic）。Lint 发现是评审提示。
2. 优先一致的对象 shape 与批量分配，而不是抠单次属性访问。
3. 嵌入 / 小程序运行时：跳过仅 DOM 的提示；同样盯分配 + `delete`（§3）。**不要**在那里套用 Turbofan/Maglev 建议。
4. 在 Node/Chrome 上，用 §4 看 elements kind、IC 多态与 deopt 检查——然后测量。
5. 对 CLI、lint/测试跑手与包冷启动，用 §5（解析、惰性 `require`、barrel）——不要只靠 jp-* 规则。

## 目录

- [0. 范围与方法](#0-范围与方法)
- [1. 分配与 shape](#1-分配与-shape)
- [2. `delete` 与 shape](#2-delete-与-shape)
- [3. 嵌入与小程序](#3-嵌入与小程序)
- [4. V8 优化（Node / Chrome）](#4-v8-优化node--chrome)
- [5. 启动与工具链（冷路径）](#5-启动与工具链冷路径)
- [Lint 对照表](#lint-对照表)
- [参考](#参考)

---

## 0. 范围与方法

1. **先管 shape** —— 按同一顺序初始化字段；避免多态热路径（§1、§4.1）。
2. **分配压力** —— `.push({…})`、`new`、非空对象绑定；默认作用域在循环外也会报（§1）。
3. **`delete`** —— 热对象上优先墓碑或并行结构（§2）；避免 `delete arr[i]` 打洞（§4.2、jp-delete-array-hole）。
4. **嵌入** —— 同样的分配/shape 规则，不假设 `window` / DOM 或 V8 分层（§3）。
5. **V8 Node/Chrome** —— elements kind、IC 状态、deopt、流水线素描（§4）。
6. **启动 / 工具链** —— 用 `--cpu-prof` profile；削减 FS/解析；惰性加载稀有路径；留意 barrel（§5）。
7. **测量** —— 重写前用 `--prof` / `--cpu-prof` / `--trace-deopt` / Performance 面板 / `examples/bench`。

来源：[XPerf playbook](../../../../docs/zh-CN/playbook.md) · [corpus.md](corpus.md) · [Marvin 系列](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)

---
