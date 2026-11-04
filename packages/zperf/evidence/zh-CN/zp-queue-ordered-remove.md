# zp-queue-ordered-remove — 队列有序移除

## 主张

在这台 Linux 机器上，使用 Zig **0.17.0** `-Ofast` 编译，ArrayList.orderedRemove(0) 排空与环形头部前进显示出明显的前后实时时间差距。

## 如何测量

- 测试工具：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-queue-ordered-remove` 用例）
- 构建：`zig build-exe -Ofast` · 优化模式=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9轮的中位数**
- **之前：** `ordered_remove_0`
- **之后：** `ring_head_advance`
- 操作数=4000
- 原始数据：[`zp-queue-ordered-remove.jsonl`](../zp-queue-ordered-remove.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~0.5391 ms |
| Median after | ~0.001157 ms |
| **前/后比率** | **~466×** |

## 与 lint 的对应

`zperf-lint` `zp-queue-ordered-remove` / `queue-ordered-remove`。`rules.zig` 中的默认严重性是 **警告**；有关保留/升级，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在并且方向上**一致**。

## 结论

同意 ~466× 用于 N=4000 的 FIFO 排水（O(N²) 移位）。

## 限制

小型有界队列仍然可以使用有序移除；如果不要求顺序，则使用交换移除。
