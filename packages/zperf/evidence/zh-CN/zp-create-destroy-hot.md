# zp-create-destroy-hot — 循环中创建和销毁

## 主张

在这台 Linux 机器上，Allocator.create/destroy(Node) 与 Zig **0.17.0** 下的 MemoryPool `-Ofast` 对比显示出明显的前后实时时钟差距。

## 如何测量

- 测试套件：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-create-destroy-hot` 的案例）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 唤醒；warm=2；**9 轮的中位数**
- **之前：** `create_destroy_loop`
- **之后：** `memory_pool`
- 操作次数=200000
- 原始数据：[`zp-create-destroy-hot.jsonl`](../zp-create-destroy-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~4.026 ms |
| Median after | ~0.375 ms |
| **前/后比例** | **~10.7×** |

## 与 lint 的对应

`zperf-lint` `zp-create-destroy-hot` / `create-destroy-in-loop`。`rules.zig` 中的默认严重性是 **信息**；有关保留/升级的详情，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在并且在方向上**一致**。

## 结论

同意 ~10.7× 的固定大小节点更替率。

## 限制

可变大小的对象需要其他池。
