# zp-alloc-hot — 循环中分配

## 主张

在这台 Linux 机器上，使用 Zig **0.17.0** `-Ofast`，每次迭代执行 GPA alloc+free 与 ArenaAllocator.reset(.retain_capacity) 显示了明显的前后实际时间差距。

## 如何测量

- 测试框架：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-alloc-hot` 情况）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 时间测量：`Io.Clock` 唤醒；热身=2；**9 轮的中位数**
- **之前：** `gpa_alloc_free_in_loop`
- **之后：** `arena_retain_in_loop`
- 操作次数=100000
- 原始数据：[`zp-alloc-hot.jsonl`](../zp-alloc-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~2.012 ms |
| Median after | ~1.422 ms |
| **前后比例** | **~1.41×** |

## 与 lint 的对应

`zperf-lint` `zp-alloc-hot` / `alloc-in-loop`。`rules.zig` 中的默认严重性是 **关闭**（CLI 不会报告该规则）；有关保留/升级，请参阅 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在并且在方向上 **一致**。

## 结论

同意 ~1.41× 但在 smp_allocator 上表现温和；FBA/池（zp-fixed-size-alloc-hot）通常更大。方向明确。

## 限制

具有微小固定大小的高频路径可能更适合使用 MemoryPool/FBA；保持 arena 是一个有效的修复方法。
