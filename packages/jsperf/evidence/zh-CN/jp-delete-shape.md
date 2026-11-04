# jp-delete-shape — 对普通成员使用 `delete`

## 主张

在 V8/Node 上，热 `delete obj.key` 比通过墓碑方式保留结构 (`obj.key = undefined`) 要慢，因为 `delete` 会改变对象映射 / 可能强制对象进入字典模式路径。

## 如何测量

- 测试工具：`packages/jsperf/examples/bench/evidence_jp003_jp004.js`（与 `static_vs_v8_correlate.js` 的第4种情况使用相同的内核）
- 工作量：N=200000 次迭代；预热=3；取 9 个 `process.hrtime.bigint` 样本的中位数
- **之前：** 构造 `{ k, keep }`，`delete o.k`，访问字段
- **之后：** 相同构造，`o.k = undefined`，访问字段
- 原始行：[`jp-delete-shape.jsonl`](../jp-delete-shape.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海（本地时间；JSONL 中的 ISO 时间戳为 UTC） |
| Node | **v20.19.2** |
| V8 | **11.3.244.8-node.38** |
| 删除对象前的中位数 (`delete_obj_k`) | ~43.2 毫秒 |
| (`tombstone_undefined`) 之后的中位数 | ~0.091 毫秒 |
| **前/后比率** | **~474×** |

在 Node v22.22.3 / V8 12.4 上的早期相关性显示在相同方向上约为 ~165×（`scripts/run-static-vs-v8.sh`）。这台机器上的之前门槛约为 ~360×。方向稳定；幅度对机器/Node 敏感——升级后重新运行测试框架。

## 与 lint 的对应

`jsperf-lint` 的 jp-delete-shape 会在 `delete obj.key` 风格的成员上触发（不是 `delete arr[i]` —— 那是 jp-delete-array-hole）。在 [evidence-policy](../../docs/zh-CN/evidence-policy.md) 下默认严重性是 **`off`**：这个 JSONL 存在并且一致，但语料筛查发现几乎所有命中都是可接受的惯用法。使用 `--preset all` 或 `--severity jp-delete-shape=error` 可以启用它。

## 限制

- 微基准测试，而不是应用程序分析。
- 一次性脚本：`--trace-deopt` 行计数是一个弱预测（实际耗时才是关键）。
- 冷启动 / 引导 `delete`（Node `internal/bootstrap/**`）被代码检查工具跳过，不属于此声明的范围。
