## 5. 启动与工具链（冷路径）

本章讲 **工具链 / 冷启动 / 模块图** 成本——不是 §1–§2 / §4 的热循环 shape 与分配味道。

主要来源：Marvin Hagemeister 系列 **[Speeding up the JavaScript ecosystem](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)**（第 1–13 部分）。下列方法经转述；**不要把他的墙钟数字当成我们的**——在你的机器上重测。

| 关注点 | 章节 | 靠什么发现 |
|--------|------|------------|
| 运行时 shape / 分配 / holey / `delete` | §1、§2、§4 | jp-* 规则 + `examples/bench` |
| 模块解析、急切 `require`、barrel、CLI 开销 | §5 | `node --cpu-prof` / speedscope、require 图检查 —— **不是** jp-* 规则 |

### 5.1 先做 profile（工具链）

重写库或 CLI 之前：

1. 抓 CPU profile：`node --cpu-prof your-tool.js …`（或对 npm 脚本 `node --cpu-prof $(which npm) run …` —— 见 [part 4](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-4/)）。
2. 在 [speedscope](https://www.speedscope.app/)（或 Chrome DevTools）打开 `.cpuprofile`。
3. 问：时间在**你的**热函数里，还是在**加载 / 解析**模块、类型转换、正则、FS？

Marvin 反复使用的方法（[part 1](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)）：找顶帧 → 打开源码 → 去掉可避免的工作 → 再 profile。与 XPerf「重写前先测」同一循环，瞄准 **构建/lint/CLI** 而非应用渲染循环。

### 5.2 热转换、短串正则、内层函数（part 1 方法）

转述自 [part 1](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)（PostCSS、SVGO 及邻居）的模式：

- **字符串 ↔ 数字搅动** —— 例如紧循环里 `toFixed` 再 `+` 回数字。优先留在数字域（`Math.round` / 按 `10**p` 缩放）。
- **对很多短串跑正则** —— 用一条正则匹配许多细碎序列化片段，往往差于对更长串单趟，或先做「针是否存在」的廉价预检。
- **热外层函数内创建的函数** —— 每次调用重建闭包伤 IC；提升助手或显式传参，而不是捕获。
- **转译器产物** —— 例如 `for…of` 被改写成每轮新鲜 `_loop` 函数；检查**已发布**输出，不要只看源码。

路径在运行时很热时，这些可与 §4（IC）重叠。在工具链里它们往往主导**启动或每文件**成本。

### 5.3 模块解析（part 2 方法）

来自 [part 2](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-2/)：在 lint/测试/构建轨迹里，解析可以压过解析（parsing）。

当作检查清单（转述他的四点）：

1. **少碰 FS** —— 规模一大，每次 `stat`/`exists` 都贵。
2. **缓存** 已解析路径（watch 模式：小心失效）。
3. **`fs.statSync(path, { throwIfNoEntry: false })`** —— 避免为「文件不存在」（ENOENT）抛错并抓栈。
4. **限制向上走 `node_modules`** —— 尤其当路径别名被误当成裸包导入时。

也留意**扩展名猜测**（`.js` → `.jsx` → … → `.ts`）以及与 TypeScript/`tsconfig` paths 不同解析器的别名插件。

**jsperf-lint 看不见这些。** 没有 jp-* 规则测 FS 或解析。配套：CPU profile、解析器缓存，以及 `examples/bench/require_cost_sketch.js` 里急切 vs 惰性素描。

### 5.4 启动：急切图、barrel、「抱着香蕉的大猩猩」

来自 [part 4](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-4/)（npm 脚本）与 [part 7](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-7/)（barrel）：

- **急切 `require` / `import`** 预先加载整个可达图。错误格式化器、审计代码、进度条——快乐路径用不到的——应**惰性**（`if (err)` 分支内 `require`，稀有命令用动态 `import()`）。
- **肥类 / mixin 堆** 拉来「抱着香蕉和整片丛林的大猩猩」（Joe Armstrong，经 Marvin）：一个入口类 mixin 了 audit + reify + rebuild，而你只需要 `run`。
- **Barrel 文件**（只 `export * from …` 的 `index.js`）放大图：一次导入可拉来一目录树；按文件 spawn 的测试跑手反复付钱。启动或 lint/测试墙钟要紧时，优先直接导入。
- CLI 的**已发布 bundle** 可缩小加载成本；要测——巨大单文件有解析权衡。

### 5.5 与 jp-* 规则的关系

| | 运行时章节（§1–§2、§4） | 本章（§5） |
|--|------------------------|-----------|
| 典型收益 | 热循环 IC / GC / elements kind | 冷启动、`npm run`、lint/测试图 |
| Lint | jp-* 规则（行窗规则） | **今天没有** —— 仅文档配套 |
| 证据 | `examples/bench/*`、`--trace-deopt` | `--cpu-prof` + speedscope；require 图大小 |

不要把干净的 jsperf-lint 自检解读成「启动没问题」。不要在没有本地 profile 的情况下把 Marvin 发表的加速当可迁移结论。

### 5.6 可选素描：急切 vs 惰性 require

`examples/bench/require_cost_sketch.js` 建一个小夹具图，计时顶层急切 `require` vs 稀有分支内惰性 `require`。这是**教学微基准**，不是关于 npm 或你的应用的声明。运行：`node examples/bench/require_cost_sketch.js`。

---
