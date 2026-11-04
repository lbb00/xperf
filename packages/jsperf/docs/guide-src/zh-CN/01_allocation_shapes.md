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

**证据（本机）：** [`evidence/jp-alloc-hot`](../../evidence/zh-CN/jp-alloc-hot.md) —— 循环内 `new Uint8Array` 对比一次 **~19×**；`.push({i})` 对比预分配填充 **~6.4×**（Node v20.19.2）。机制是分配/GC（STATIC-VS-V8 对 deopt 为 PARTIAL）。默认严重级别 **off**（`--preset all` 或 `--severity jp-alloc-hot=hint` 开启）——见 [evidence-policy](evidence-policy.md)。默认 **`--scope all`** 在循环外也报；`--scope loop` 恢复仅循环内匹配。

### 1.3 语料 dogfood（启发式）

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

Lint：**jp-map-filter-chain** —— 默认 **hint**。匹配前剥掉 `//` 与块注释。codegen `gen-*.js` 路径跳过。证据：[`jp-map-filter-chain`](../../evidence/zh-CN/jp-map-filter-chain.md)。

---
