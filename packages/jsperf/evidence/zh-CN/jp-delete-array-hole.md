# jp-delete-array-hole — `delete arr[i]`（稀疏数组）

## 主张

在一个紧凑数组上使用 `delete a[i]` 会创建一个**有孔的**元素类型；随后进行类似密集数组的求和操作，比在 V8/Node 上保持紧凑数组要慢。

## 如何测量

- 测试工具：`packages/jsperf/examples/bench/evidence_jp003_jp004.js`（与 `static_vs_v8_correlate.js` 的案例 2 使用相同的内核）
- 工作量：N=200000；预热=3；9 轮的中位数
- **之前：** 填充 packed，`delete a[i]` 对偶数 i，求和已定义的槽
- **之后：** 填充 packed，求和所有槽（不删除）
- 原始数据行：[ `jp-delete-array-hole.jsonl`](../jp-delete-array-hole.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 |
| Node | **v20.19.2** |
| V8 | **11.3.244.8-node.38** |
| 中位数之前 (`holey_delete_arr_i`) | 约 5.14 毫秒 |
| (`packed_fill_sum`) 后的中位数 | ~1.63 毫秒 |
| **前/后比例** | **~3.2×** |

节点 v22.22.3 的相关性之前在同一方向上大约为 ~5.5×。在引用单一系数之前，最好在你的节点上重新测量。

## 与 lint 的对应

jp-delete-array-hole 标志使用计算索引（`arr[i]`）的 `delete`。根据 [evidence-policy](../../docs/zh-CN/evidence-policy.md)，严重性为 **错误**。

## 限制

- 填充+求和微基准；实际应用可能更喜欢使用 `splice` / filter / dense tombstones 来实现语义，而不仅仅是速度。
- 多孔数组也可能因为跳过的索引而出现，而不使用 `delete`——lint 不会检测到这些。
- 这种情况下的去优化追踪十分嘈杂；门槛是实时时钟的比例。
