# jp-alloc-hot — 分配类模式

## 主张

热的每次迭代分配（清空容器/缓冲区的 `new`，`.push({…})`）在 V8/Node 上比重用/预分配更慢，主要是由于 **分配/垃圾回收成本**，而不是由于去优化/IC 失败。

## 如何测量

- 测试工具：`packages/jsperf/examples/bench/evidence_jp001_jp002.js`
- 配对 A（对应 `static_vs_v8_correlate.js` 的案例 5）：N=200000；预热=3；取 9 次的中位数
  - **之前：** 循环内使用 `new Uint8Array(16)`
  - **之后：** 循环外创建一个 `Uint8Array`；在循环中修改它
- 配对 B：N=200000
  - **之前：** `.push({ i })` 添加元素
  - **之后：** `new Array(N)` 填充 + 求和（语义不同 — 仅用于速度参考）
- 原始数据行：[`jp-alloc-hot.jsonl`](../jp-alloc-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海（本地时间；JSONL 中的 ISO 时间戳为 UTC） |
| Node | **v20.19.2** |
| V8 | **11.3.244.8-node.38** |
| 循环前的中位数 (`new_in_loop`) | ~4.66 毫秒 |
| (`new_once_outside`) 之后的中位数 | ~0.24 毫秒 |
| **ratio new_in_loop / once** | **~19×** |
| `push_object_literal` 之前的中位数 | ~10.9 毫秒 |
| (`prealloc_fill_sum`) 后的中位数 | ~1.69 毫秒 |
| **推送/预分配比率** | **~6.4×** |

早期在 Node v22.22.3 / V8 12.4 上的相关性显示 Uint8Array 对 (`scripts/run-static-vs-v8.sh`) 约为 ~**49×**。方向稳定；幅度受 Node/机器影响。

## 与 lint 的对应

`jsperf-lint` jp-alloc-hot 标记 `.push({` / 非空绑定器 / 清除 `new` / `Object.create`。默认 `--scope all` 也会报告循环外的这些模式；`--scope loop` 则只匹配循环内的前者。默认严重性在 [evidence-policy](../../docs/zh-CN/evidence-policy.md) 下为 **`off`**（使用 `--preset all` 或 `--severity jp-alloc-hot=hint` 可启用）：实测时间一致，但机制是 GC/分配 — **不是** JIT/去优化门控 — 并且遗留的 Node `lib/` 命中需要人工审查（SafeMap、一次初始化、流）。

## 限制

- 微基准；不是应用程序配置文件。
- Pair B 改变结果形状（对象 vs 整数）——仅作为“构建者税”示例使用。
- **不要**将 jp-alloc-hot 与 deopt/IC 失败等同（STATIC-VS-V8 案例 5）。
- Marvin §05（启动/工具）不在此运行时检查范围内。
