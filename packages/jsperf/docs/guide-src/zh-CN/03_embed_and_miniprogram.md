## 3. 嵌入与小程序

### 3.1 同样的物理，更小的运行时

QuickJS、Hermes 类嵌入与小程序 JS 运行时仍要为这些付钱：

- 每轮对象分配（jp-alloc-hot 模式）。
- 经 `delete` 或分叉属性顺序导致的 shape 变化。
- 紧循环里的日志（**jp-console-hot** —— `console.log` / `console.debug`）。证据：[`jp-console-hot`](../../evidence/zh-CN/jp-console-hot.md)（即便丢弃 stdout 仍约 **1300×** 对比安静）——默认 **off**（`app`）/ **hint**（`engine`），不是 CI error。

它们往往**没有**浏览器 Performance 面板、DOM 或大 IC 预算。以「打开 DevTools → …」开头的建议迁不过来。优先：

- §1–§2 的分配/shape 纪律。
- 宿主暴露批处理 API 时批量工作（`examples/p02_batch_note.js`），而不是每帧 microtask。
- 用**宿主** profiler 测量（Node `--prof`、QuickJS 计时钩子、厂商小程序 perf 面板）——不是仅 Chrome 工作流。

**不要**把 §4（Maglev/Turbofan、elements-kind 迁移、`--trace-deopt`）套到这些运行时。稳定 shape 与更少分配仍然有用；V8 分层话术没有。

### 3.2 共享的 quickjs 树

cperf dogfood **C** 引擎；jsperf dogfood 旁边的 `*.js`（跳过测试与 `gen-*`）。当前规则在那里报 **0**（[corpus.md](corpus.md)）；较早修订报过 2 个 jp-alloc-hot。压力低，但作为邻接嵌入的样本有用。不要指望生成脚本有 Preact 级干净。

### 3.3 这里不该推荐什么

- 把 DOM 批处理 / `requestAnimationFrame` 当主修复。
- `innerHTML` vs `createElement` 争论。
- 仅浏览器 API（嵌入可能不提供的 `WeakRef` + FinalizationRegistry 模式）。
- §4 的 Turbofan / Maglev / elements-kind 调优。

Typed array 与一致 shape 仍然可移植（`examples/p01_typed_array.js`、`m01_hidden_class.js`）。

---
