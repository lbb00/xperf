# zp-page-allocator-small — page-allocator-small

## 主张

在这台 Linux 机器上，使用 Zig **0.17.0** `-Ofast`，page_allocator 64B 分配+释放与进程 GPA（smp/c 在 ReleaseFast 下）的对比显示了明显的前后墙钟差距。

## 如何测量

- 测试工具：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-page-allocator-small` 情况）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9轮的中位数**
- **之前：** `page_allocator_64B`
- **之后：** `process_gpa_64B`
- 操作次数=20000
- 原始数据：[`zp-page-allocator-small.jsonl`](../zp-page-allocator-small.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~137.1 ms |
| Median after | ~0.4018 ms |
| **前/后比率** | **~341×** |

## 与 lint 的对应

`zperf-lint` `zp-page-allocator-small` / `page-allocator-small`。`rules.zig` 中的默认严重性为 **警告**；有关保留/升级，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在并且方向上**一致**。

## 结论

同意 ~341× — 页面分配器对每个小块付出 syscall/页面。

## 限制

大型 mmap 大小的缓冲区仍然可以故意使用页面分配器。
