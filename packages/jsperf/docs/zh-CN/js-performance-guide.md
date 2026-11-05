# JavaScript 性能指南（v0）

稳定的 shape、更少的每轮分配——另有一章讲工具链 / 冷启动。

> **焦点：现代 Node 与 V8（inline cache / GC）。** QuickJS 与小程序类嵌入有专章（§3）——跳过需要 DOM 或完整浏览器 profiler 的建议。§4 只讲 V8（map、elements kind、deopt、Ignition → Maglev/Turbofan），不适用于 §3 运行时。§5 讲启动与工具链（模块解析、急切图、barrel），依据 Marvin Hagemeister 的生态系列；这类成本不在 jp-* 规则里。
>
> 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。§4.6 只引用单机微基准中位数。§5 引用 Marvin 的方法（URL）；他的计时请在本地重测。
>
> 配套：`jsperf-lint/` —— jp-* 规则，见 [Lint 对照表](#lint-对照表)（行窗；非完整解析器）。已在 Node `lib/`、Preact `src/`、quickjs `*.js`（跳过测试）以及 TypeScript `packages/typescript/src` 上跑过（2026-10-21 Asia/Shanghai）。见 [corpus.md](corpus.md)。启动与 FS 成本对 jp-* 规则是带外的——见 §5。

先做 profile（`node --prof`、`node --cpu-prof` + speedscope、Chrome Performance、clinic）。优先一致的对象 shape 与批量分配，而不是抠单次属性访问。嵌入 / 小程序跳过 DOM 提示，也不要套用 Turbofan/Maglev。在 Node/Chrome 上用 §4 看 elements kind、IC 多态与 deopt。对 CLI、lint/测试跑手与包冷启动用 §5。

## 目录

- [0. 范围与方法](#0-范围与方法)
- [1. 分配与 shape](#1-分配与-shape)
- [2. `delete` 与 shape](#2-delete-与-shape)
- [3. 嵌入与小程序](#3-嵌入与小程序)
- [4. V8 优化（Node / Chrome）](#4-v8-优化node--chrome)
- [5. 启动与工具链（冷路径）](#5-启动与工具链冷路径)
- [6. 构造、JSON、DOM 查询与日期格式](#6-构造jsondom-查询与日期格式)
- [Lint 对照表](#lint-对照表)
- [参考](#参考)

---

## 0. 范围与方法

1. 先管 shape —— 按同一顺序初始化字段；避免多态热路径（§1、§4.1）。
2. 分配压力 —— `.push({…})`、`new`、非空对象绑定；默认作用域在循环外也会报（§1）。
3. `delete` —— 热对象上优先墓碑或并行结构（§2）；避免 `delete arr[i]` 打洞（§4.2、jp-delete-array-hole）。
4. 嵌入 —— 同样的分配/shape 规则，不假设 `window` / DOM 或 V8 分层（§3）。
5. V8 Node/Chrome —— elements kind、IC 状态、deopt、流水线素描（§4）。
6. 启动 / 工具链 —— 用 `--cpu-prof` profile；削减 FS/解析；惰性加载稀有路径；留意 barrel（§5）。
7. 测量 —— 重写前用 `--prof` / `--cpu-prof` / `--trace-deopt` / Performance 面板 / `examples/bench`。

来源：[XPerf playbook](../../../../docs/zh-CN/playbook.md) · [corpus.md](corpus.md) · [Marvin 系列](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)

---
## 1. 分配与 shape

### 1.1 Hidden class（shape）

引擎（V8 及同类）按属性添加顺序分配 **hidden class** / map。热循环里分叉的 shape 会迫使多态或 megamorphic IC。

- 按一致顺序初始化全部字段（`return { x, y, z: 0 }`）。
- 避免先加不同属性的 `if` 分支。
- 见 `examples/m01_hidden_class.js`（示意；无计时声明）。

### 1.2 循环内分配（jp-alloc-hot）

每轮分配会在循环很热时制造垃圾与 GC 停顿：

| 模式 | Lint？ | 备注 |
|------|--------|------|
| `.push({…})` / `.push([…])` | 是 | 经典 builder 噪声 |
| 循环内非空 `{…}` / `[…]` 绑定 | 是 | 每轮逃逸的 options bag |
| 循环内 `new Ctor` / `Object.create` | 是（r2+） | 除外 `throw new` / `Error` / `ERR_*` |
| 空 `{}` / `[]` 绑定 | **否**（r2） | 每重试一次的 opts bag 在 Node 上是噪声 |
| `throw new …` | 否 | 错误路径 |

当 profile 显示有 GC 时间时，优先 typed array（`examples/p01_typed_array.js`）、对象池或预分配结构——不要默认改掉每一个 `.push`。

**证据（本机）：** [`evidence/jp-alloc-hot`](../../evidence/zh-CN/jp-alloc-hot.md) —— 循环内 `new Uint8Array` 对比一次 **~19×**；`.push({i})` 对比预分配填充 **~6.4×**（Node v20.19.2）。机制是分配/GC（STATIC-VS-V8 对 deopt 为 PARTIAL）。默认严重级别 off（`--preset all` 或 `--severity jp-alloc-hot=hint` 开启）——见 [evidence-policy](evidence-policy.md)。默认 **`--scope all`** 在循环外也报；`--scope loop` 恢复仅循环内匹配。

### 1.3 语料命中（lint 计数）

下表来自 lint 行窗的较早修订（r1–r3），展示启发式如何收窄；当前语料结果见 [corpus.md](corpus.md)。

| 语料 | r1 → r2 → r3 | 备注 |
|------|--------------|------|
| Node `lib/` | 60 → 179 → **115**（jp-alloc-hot **33 → 158 → 94**；jp-delete-shape 27 → 21 → 21） | r2 有意纳入 `new` / 非空绑定抬高了 jp-alloc-hot；r3 注释/`for` 误报削减。残留：`inspect.js` `new SafeMap()`（~16）、stream `pull.js` / `share.js` / `broadcast.js` 的 `IterResult` / `Uint8Array`、`abort_controller.js` 真实 `for` 里的 `??= new SafeSet()` |
| Preact `src/` | **0 → 0 → 0** | 干净基线——对框架核心规则可能偏窄（很少 `.push({` / 循环 `new`） |
| quickjs `*.js` | 5 → 4 → **2** jp-alloc-hot | 跳过 tests/；剩 codegen 味脚本 |
| TypeScript `packages/typescript/src` | — → 47 → **15** jp-alloc-hot | Go 迁移后 tip（~50 `.ts`）；注释/循环修复有帮助。经典 `src/compiler` 不在本树 |

**怎么读 Node 残留：** 真实循环里的 once-init `??= new` 往往是**真**分配（相对 `.push({` 的严重档仍开放）。`inspect.js` 的 SafeMap 构造可能邻接循环却非每元素热路径——评审，不要批量重写。

### 1.4 真正管用的反向优化

- 丢掉空 `{}`/`[]` 绑定（r2）——消灭 Node options-bag 噪声；保留 `.push({`。
- 多行块注释 + 无花括号 `for` 修复（r3）——JSDoc 里的 `for` 与 `for (…)\n stmt;` 不再打开假循环（Console 原型安装等）。
- 夹具：`good/empty_opts_in_loop.js`、`good/comment_for_not_loop.js`、`good/throw_new_in_loop.js`、`good/jp-alloc-hot_reuse_buffer.js`、`bad/jp-alloc-hot_new_in_loop.js`、`bad/jp-alloc-hot_push_object.js`。

### 1.5 循环里字符串 `+=`（已移除）

`jp-string-plus-in-loop` 曾匹配字符串字面量或 `String.fromCharCode` 的 `+=`，并建议改成 `push` 再 `join`。在匹配器命中的 shape 上，该重写大约没有 2× 收益（Node v24.18.0，V8 13.6.233.17-node.50）。

| Shape | `+=` ms | `join` ms | `+=` / `join` |
| --- | ---: | ---: | ---: |
| `"\n"` × 100，重复 200 | 0.194 | 0.126 | 1.53 |
| `"\n"` × 22000，重复 20 | 1.648 | 2.756 | 0.60 |
| `"\n"` × 44000，重复 10 | 1.459 | 3.176 | 0.46 |
| `String.fromCharCode` × 22000，重复 10 | 0.893 | 2.647 | 0.34 |
| 64 字符字面量 × 700，重复 40 | 0.070 | 0.226 | 0.31 |
| `obj.s += "\n"` × 22000，重复 10 | 0.759 | 1.816 | 0.42 |

比值接近 2 表示 `join` 快一倍。100 换行那例是 1.53×，未达门槛。22000 与 44000 字符时 `join` 更慢。V8 已对循环 `+=` 建串。`push` 再 `join` 还要分配指针数组。匹配器已删。墓碑：[`jp-string-plus-in-loop`](../../evidence/_removed/jp-string-plus-in-loop.REMOVED.md)。

### 1.6 链式 `.map` / `.filter`（jp-map-filter-chain）

`.filter().map()` 每次调用分配中间数组。成本随长度与趟数增长。3 行列表与 35000 行表不是同一成本。

本机（与 §1.5 相同 Node）两边都构建结果数组：

| Shape | 链式 ms | 单趟 ms | 比值 |
| --- | ---: | ---: | ---: |
| 3 行，filter 再 map，× 20000 | 0.289 | 0.226 | 1.28× |
| 3 行，四次 filter 再 map，× 20000 | 0.761 | 0.220 | 3.46× |
| 35000 行，filter 再 map，× 20 | 8.728 | 1.898 | 4.60× |
| 35000 行，四次 filter 再 map，× 20 | 12.850 | 1.306 | 9.84× |

3 行 filter-then-map 低于 2×。3 行四趟高于 2×，但 20000 次仍在一毫秒内。35000 行才是单趟明显更快的地方。hint 点名长度。短列表重写可选。

Lint：**jp-map-filter-chain** —— 默认 hint。匹配前剥掉 `//` 与块注释。codegen `gen-*.js` 路径跳过。证据：[`jp-map-filter-chain`](../../evidence/zh-CN/jp-map-filter-chain.md)。

---
## 2. `delete` 与 shape

### 2.1 为什么热对象上的 `delete` 伤性能

`delete obj.key` 改变对象的 hidden class。引擎可能掉下 monomorphic IC；空洞在某些路径上会逼进 dictionary 模式。优先：

- 字段可选且希望 shape 稳定时，用 `obj.key = undefined` / `null`。
- 「是否存在」很常见时，用并行 `Set` / bitset / 稠密旁表。
- 在冷路径重建新对象，而不是在热循环里 delete。

Lint：**jp-delete-shape** —— 成员表达式上的 `delete`（文件级启发式；默认不限循环）。实测门禁：[`evidence/jp-delete-shape`](../../evidence/zh-CN/jp-delete-shape.md)（相对墓碑约 **474×**，Node v20.19.2）；JSONL 同意，但语料 triage 发现命中几乎全是 OK 惯用法（见 [evidence-policy](evidence-policy.md)），故默认 off（`--preset all` 或 `--severity jp-delete-shape=error` 开启）。

### 2.2 有意的 `delete`（bootstrap / 功能剥离）

Node 的 `lib/internal/bootstrap/**` 用 `delete` 做模块缓存与功能剥离。那是启动 / 一次性，不是每请求热路径。

**jsperf-lint：** 对 jp-delete-shape 与 jp-delete-array-hole 跳过 `internal/bootstrap/` 下文件、匹配 `*bootstrap*` 的文件名，以及 inspect/debugger/test-runner 路径。

证据（语料命中）： Node `lib/` jp-delete-shape 在 bootstrap 跳过后 **27 → 21**（r1→r2）；r3 保持 **21**，同时 jp-alloc-hot 在动。剩余 delete 需逐案评审（CLI 拆卸、稀有 map）。

### 2.3 可选的未来

`--hot-only`（要求 jp-delete-shape 有循环上下文）尚未交付。在此之前，把循环外的 jp-delete-shape 当作 shape 味道，而不是自动 bug。

---
## 3. 嵌入与小程序

### 3.1 同样的物理，更小的运行时

QuickJS、Hermes 类嵌入与小程序 JS 运行时仍要为这些付钱：

- 每轮对象分配（jp-alloc-hot 模式）。
- 经 `delete` 或分叉属性顺序导致的 shape 变化。
- 紧循环里的日志（**jp-console-hot** —— `console.log` / `console.debug`）。证据：[`jp-console-hot`](../../evidence/zh-CN/jp-console-hot.md)（即便丢弃 stdout 仍约 **1300×** 对比安静）——默认 off（`app`）/ hint（`engine`），不是 CI error。

它们往往**没有**浏览器 Performance 面板、DOM 或大 IC 预算。以「打开 DevTools → …」开头的建议迁不过来。优先：

- §1–§2 的分配/shape 纪律。
- 宿主暴露批处理 API 时批量工作（`examples/p02_batch_note.js`），而不是每帧 microtask。
- 用**宿主** profiler 测量（Node `--prof`、QuickJS 计时钩子、厂商小程序 perf 面板）——不是仅 Chrome 工作流。

不要把 §4（Maglev/Turbofan、elements-kind 迁移、`--trace-deopt`）套到这些运行时。稳定 shape 与更少分配仍然有用；V8 分层话术没有。

### 3.2 共享的 quickjs 树

cperf 在 **C** 引擎上跑；jsperf 在 旁边的 `*.js`（跳过测试与 `gen-*`）。当前规则在那里报 **0**（[corpus.md](corpus.md)）；较早修订报过 2 个 jp-alloc-hot。压力低，但作为邻接嵌入的样本有用。不要指望生成脚本有 Preact 级干净。

### 3.3 这里不该推荐什么

- 把 DOM 批处理 / `requestAnimationFrame` 当主修复。
- `innerHTML` vs `createElement` 争论。
- 仅浏览器 API（嵌入可能不提供的 `WeakRef` + FinalizationRegistry 模式）。
- §4 的 Turbofan / Maglev / elements-kind 调优。

Typed array 与一致 shape 仍然可移植（`examples/p01_typed_array.js`、`m01_hidden_class.js`）。

---
## 4. V8 优化（Node / Chrome）

本章针对 **V8** 深化 §1。不适用于 QuickJS、Hermes 类嵌入或小程序运行时——见 §3。那些引擎共享「稳定 shape / 更少分配」的物理；它们**得不到** Ignition → Maglev/Turbofan 建议、elements-kind 迁移或 `--trace-deopt` 工作流。

按 **Node 22+ / 现代 V8 连续体** 标注日期（测于 Node v22.22.3，V8 12.4.x）。流水线层级名与标志会漂；把下面的版本钉当作「我们跑过什么」，不是永远保证。

### 4.1 Hidden class / map 与 IC（扩展 §1.1）

V8 给每个对象挂一个 **map**（hidden class）。属性添加顺序与类型反馈建过渡树。属性读写走 **内联缓存（IC）**：

| IC 状态 | 含义（实践） |
|---------|--------------|
| Monomorphic | 只见过一个 map —— 热读写的最佳情况 |
| Polymorphic | 少数 map（小固定集）—— 仍可优化，更慢 |
| Megamorphic | 很多 map —— IC 放弃；走通用慢路径 |

**要做：** 用一种字段顺序构造（`{ x, y, z: 0 }`）；让热调用点落在同一 shape。**不要：** 分支成有的对象先 `x` 后 `y`、有的反过来；不要在热对象上 `delete` 字段（§2）。

微基准：`examples/bench/shape_mono_vs_poly.js`（同序 vs 分叉构造；数字见 §4.6）。

### 4.2 Elements kind

数组不是单一表示。V8 跟踪 **elements kind**，大致：

| Kind（概念） | 典型内容 |
|--------------|----------|
| `PACKED_SMI_ELEMENTS` | 稠密小整数，无洞 |
| `PACKED_DOUBLE_ELEMENTS` | 稠密浮点（出现非 Smi 数之后） |
| `PACKED_ELEMENTS` | 稠密对象/值混合 |
| `HOLEY_*` | 同族**带洞**（缺索引） |

**实践要/不要：**

- 优先稠密 `push` / 预分配（`new Array(n)` 再填 0..n-1），而不是稀疏写。
- **不要打洞：** `delete arr[i]`，或跳索引（`arr[0]=1; arr[2]=2`），会逼进 holey kind 与更弱的优化代码。
- 数值热循环优先 **typed array**（`Float64Array`、`Uint32Array` …）：固定元素类型、无 holey 迁移、连续存储。普通 `number[]` 可以保持 packed，但混合 Smi/double 迁移与装箱仍有成本。
- 读过 `length` 或把洞当「可选槽」是 shape 味道；必须时用并行长度、typed 位掩码，或在**packed** 数组上用 `undefined` 墓碑。

Lint：**jp-delete-array-hole** 标记 `delete arr[i]` 式成员删除（holey 风险）；实测门禁 [`evidence/jp-delete-array-hole`](../../evidence/zh-CN/jp-delete-array-hole.md)（约 **3.2×**）。jp-delete-shape 覆盖普通成员上的 `delete obj.key`；历史上漏掉计算索引删除——jp-delete-array-hole 补上。

微基准：`examples/bench/elements_packed_vs_holey.js`、`examples/bench/typed_array_vs_number_array.js`。

### 4.3 Deopt —— 何时要紧；怎么查

**Deopt** 因假设被打破（意外 map、elements kind、边界等）把优化代码打回更慢层级。启动时或稀有路径上偶发 deopt 正常。当它落在 profile 到的热函数上并每轮重复时，deopt **要紧**。

**静态 jsperf-lint 无法检测 JIT 结果。** IC 状态、deopt 与优化层级是运行时事实。jp-* 规则只标分配/shape *味道*。JIT 验证 = profile / `--trace-deopt` / bench —— 绝不是「linter 说了算」。

**运行时 harness（不是 lint 规则）：**

```sh
# 跨 Node 版本优先：
node --trace-deopt examples/bench/deopt_probe.js
bash scripts/jit-check.sh   # 写入 examples/bench/out/deopt-sample.txt

# 可选 / 脆弱：V8 natives（状态码会漂）
USE_NATIVES=1 node --allow-natives-syntax --trace-deopt examples/bench/deopt_probe.js
```

本机（Node v22.22.3）上，`deopt_probe` 先把 `hotLoad` 暖成 monomorphic 再喂分叉 map；`--trace-deopt` 报告：

`[bailout … reason: wrong map … JSFunction hotLoad … Code TURBOFAN]`

一次性 `-e` 脚本也常打印 “Insufficient type feedback …” —— 当作**启动噪声**，不是味道已热的证明。

**检查（Chrome）：** Performance 面板 → 可用处的 V8 标记；与改前/改后墙钟对照。不要编造加速百分比。

### 4.4 流水线素描（Ignition → Maglev / Turbofan）

高层上，现代 V8/Node：

1. **Ignition** —— 字节码解释器；收集类型反馈。
2. **Maglev** —— 中层优化编译器（当前 Node 22+ / 近版 V8 有；确切启用可取决于标志与负载）。
3. **Turbofan** —— 热代码的顶层优化编译器。

代码升温时可能爬层级，deopt 时回落。不要过度声称「Node N 上总是 Maglev」或钉死确切层级阈值——它们会动。对没有这条流水线的嵌入（§3），完全跳过层级话术。

### 4.5 jsperf-lint 能看见与不能看见什么

**硬限制：** 静态 jp-* 规则**不能**识别 JIT 优化成败。没有规则观察 monomorphic vs mega IC、Maglev/Turbofan 层级或 deopt。

| 规则 | 看见 | **看不见** |
|------|------|------------|
| jp-alloc-hot | `.push({`、非空绑定、清晰的 `new` 容器（默认 scope all） | IC 多态；分配是否导致 deopt（通常不会——导致 GC） |
| jp-console-hot | `console.*`（默认 scope all） | 即使不在热路径上，日志是否值得门控 |
| jp-delete-shape | `delete obj.key` 式成员 | 是否已是 dictionary 模式；deopt vs「只是慢」 |
| jp-delete-array-hole | `delete arr[i]`（holey） | 运行时 elements kind；无 `delete` 的跳索引打洞 |
| jp-string-plus-in-loop | 已移除 | 匹配到的 `+=` shape 上 `push` + `join` 大约没有 2× |
| jp-map-filter-chain | 一行上的链式 `.map` / `.filter` / `.flatMap` | 数组长度；3 行链与 35000 行链成本不同 |

Lint = 分配/shape 味道。JIT 验证 = `jit-check.sh` / `--trace-deopt` / `examples/bench`。多态 IC **没有** jp-* 指纹。

### 4.6 本机实测（Node v22.22.3）

经 `scripts/run-v8-benches.sh` → `examples/bench/out/`，跑于 2026-10-21 18:49 Asia/Shanghai。Node **v22.22.3**，V8 **12.4.254.21-node.56**，linux x64。预热 3 + 9 轮；下表为中位数。**仅单机数字** —— 不是跨机声明。

| Bench | 变体 | N | 中位 ms | Ops/s（约） |
|-------|------|---|----------|-------------|
| shape_mono_vs_poly | mono（同字段序） | 2e5 | **0.219** | ~9.1e8 |
| shape_mono_vs_poly | poly（分叉序） | 2e5 | **1.435** | ~1.4e8 |
| elements_packed_vs_holey | packed fill+sum | 2e5 | **1.227** | ~1.6e8 |
| elements_packed_vs_holey | 经 `delete` 的 holey | 2e5 | **4.589** | ~4.4e7 |
| elements_packed_vs_holey | 经跳索引的 holey | 2e5 | **1.445** | ~1.4e8 |
| typed_array_vs_number_array | 稠密 `number[]` fill+sum | 1e6 | **5.217** | ~1.9e8 |
| typed_array_vs_number_array | `Float64Array` fill+sum | 1e6 | **5.948** | ~1.7e8 |

**怎么读：** 此处 poly shape 比 mono 慢约 **6.5×**；`delete`-holey 比 packed 慢约 **3.7×**。跳索引 holey 写的槽更少——比较 kind 行为，不要只比原始速度。在本稠密 double 负载上 `number[]` **略快于** `Float64Array`；typed array 仍对固定元素类型、避免 packed→holey / Smi→double 迁移以及二进制/WASM 边界有意义——测你的循环。

完整 JSONL：`examples/bench/out/results.jsonl`（脚本写出）。

### 4.7 对照：静态味道 vs V8 时间（PARTIAL）

实验：`examples/bench/static_vs_v8_correlate.js` · `scripts/run-static-vs-v8.sh`（Node **v22.22.3**）。

| 案例 | 静态味道？ | 比值（味道/干净） | 同意？ |
|------|------------|-------------------|--------|
| Mono vs poly shape | 仅 poly | **12.0×** | **YES**（+ mono→poly 上的 `wrong map` deopt） |
| Packed vs holey `delete a[i]` | 类 jp-delete-array-hole | **5.47×** | **YES**（时间）；deopt 嘈杂 |
| `Float64Array` vs holey `number[]` | holey | **1.34×** | **PARTIAL**（弱化） |
| `delete obj.k` vs `= undefined` | jp-delete-shape | **165×** | **YES**（时间）；deopt 计数相近 |
| 对照：循环 `new` vs 一次 | jp-alloc-hot | **49.3×** | **PARTIAL** —— 分配/GC 痛，不是 deopt |

**不要假装 jp-* 规则等于 JIT 意识。** 对 shape / holey / 热 `delete` 同意最强；用 deopt 行数当神谕，或推销 typed array 总是快于 packed double 时最弱。

**JSONL 门禁（本机 Node v20.19.2，重跑 `scripts/regen-evidence.sh`）：** jp-delete-array-hole 约 **3.2×** → error；jp-delete-shape 约 **474×**（语料命中几乎全是 OK 惯用法）→ off；jp-alloc-hot 约 **19×**（分配/GC）→ off；jp-console-hot 约 **1328×**（丢弃 sink，依赖环境）→ off（`app`）/ hint（`engine`）。见 [`evidence-policy`](evidence-policy.md) 与 `evidence/jp-*.md`。

---
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
## 6. 构造函数、JSON、DOM 查询与日期格式

下列每条 hint 对应一种实测 shape。hint 行陈述该前提。只是看起来像的调用不给那套重写。默认 **`--scope all`** 到处报告这些味道——极端栈把点滴成本也算进范围，即便不在循环里。可选用 **`--scope loop`** 恢复从前的仅循环内匹配。消息不会告诉读者或模型可以忽略非循环位点。

`new RegExp(pattern)` 在模式不变时每次调用都编译。正则字面量会被缓存。若模式是循环变量或 `parts[i]`，检查器不会说编译一次。基准编译一个固定模式，Node 26 上约 4.4×。

对不变文本的 `JSON.parse`，相对解析一次，Node 26 上约 140×。对不变值的 `JSON.stringify` 是同一 shape。JSONL 行或 `rows[i]` 每轮文本不同。检查器跳过参数就是循环绑定的情况。它不会让你把那些行折叠成一次 parse。

对不变选择器的 `querySelector` / `getElementById`，在 Node 26、很小的 linkedom 文档上约 16×。由循环下标拼出的选择器不是那个基准。用不变 locale 与选项的 `new Intl.DateTimeFormat`，Node 26 上约 36×；两边仍会 format。`new Date` 不是本规则。

对不变路径的 `fs.readFileSync`，相对读一次，Node 26 上约 114×。在 `--scope loop` 下，只匹配 `{` 后的循环体（只跑一次读的 `for` 可迭代随后被跳过）。默认 `--scope all` 下，路径稳定时无论出现在哪都会报。每轮变化的路径（循环绑定）不报。

`Date.now` 约 26×，`performance.now` 约 19×，相对只采样一次，在不 wait 的紧循环里。含 `await` 的循环，或 `for await` 循环，时钟规则不报。不需要每次新鲜时间时采样一次。必须每轮读时钟的限流器没有可搬的东西。

**jp-regex-ctor-hot** 与 **jp-json-hot** 在 app 与 engine preset 上保持 hint。两者有 JSONL，2026-10-22 裁决未覆盖。**jp-dom-query-hot**（Node 26、很小 linkedom 约 16×）与 **jp-intl-datetimeformat-hot**（Node 26 约 36×，两边仍 format）有 JSONL 且保持 hint。它们在该裁决之外。`--preset all` 对仍存在的每条规则是 error。

`Reflect.get` 约 8×，未给规则。

Lint: `jp-regex-ctor-hot`, `jp-json-hot`, `jp-dom-query-hot`, `jp-intl-datetimeformat-hot`, `jp-readfile-sync-hot`, `jp-clock-hot`（默认 hint）
### Lint 对照表

| ID | 主题 | 严重级别 | 证据 / 备注 |
|----|------|----------|-------------|
| jp-alloc-hot | 对象/数组/`new` 分配 | off（`all`：error） | [`jp-alloc-hot`](../../evidence/zh-CN/jp-alloc-hot.md) ~19× / ~6.4× —— GC/分配，非 deopt |
| jp-console-hot | `console.*` | hint（`engine`）/ off（`app`） | [`jp-console-hot`](../../evidence/zh-CN/jp-console-hot.md) ~1328× 丢弃 sink —— 依赖环境 |
| jp-delete-shape | 普通成员上的 `delete` | off（`all`：error） | [`jp-delete-shape`](../../evidence/zh-CN/jp-delete-shape.md) 相对墓碑 ~474×；语料命中几乎全是 OK 惯用法 |
| jp-delete-array-hole | 计算索引上的 `delete`（holey 数组） | error | [`jp-delete-array-hole`](../../evidence/zh-CN/jp-delete-array-hole.md) 相对 packed ~3.2× |
| jp-map-filter-chain | 链式 `.map` / `.filter` / `.flatMap` | hint | 长数组约 4.6×–9.8×；3 行 filter+map 为 1.28× |
| jp-regex-ctor-hot | `new RegExp`，模式非循环绑定 | hint | Node 26 固定模式约 4.4×；优先字面量或一次共享编译 |
| jp-json-hot | `JSON.parse` / `stringify`，文本非循环绑定 | hint | Node 26 不变文本约 140×；稳定时复用 |
| jp-dom-query-hot | DOM 查询，选择器非循环绑定 | hint | Node 26、很小 linkedom 上 JSONL 约 16×；未做语料 triage |
| jp-intl-datetimeformat-hot | `new Intl.DateTimeFormat` | hint | Node 26 约 36×；两边仍 format；未做语料 triage |
| jp-readfile-sync-hot | `readFileSync`，路径非循环绑定 | hint | Node 26，不变路径约 114× |
| jp-clock-hot | `Date.now` / `performance.now` | hint | Node 26 无 `await` 时约 70× / 110×；不需要新鲜时间时采样一次 |
| *（无）* | 模块解析 / 急切图 / barrel | — | §5 —— 用 `--cpu-prof` |

上表严重级别为默认 `app` preset。匹配作用域默认为 **`--scope all`**（到处）；`--scope loop` 恢复仅循环内匹配。策略：[`evidence-policy.md`](evidence-policy.md)。夹具：`jsperf-lint/fixtures/{bad,good}/`。

### 参考

- [corpus.md](corpus.md)
- `examples/bench/` · `scripts/run-v8-benches.sh` · `scripts/jit-check.sh` · `scripts/run-static-vs-v8.sh` · `scripts/regen-evidence.sh` · `examples/bench/require_cost_sketch.js`
- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
- Marvin Hagemeister — [Speeding up the JavaScript ecosystem](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)（第 1–13 部分；§5 引用方法）
