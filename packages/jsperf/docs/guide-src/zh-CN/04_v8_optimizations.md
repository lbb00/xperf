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
