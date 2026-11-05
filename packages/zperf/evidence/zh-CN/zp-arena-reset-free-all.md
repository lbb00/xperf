# zp-arena-reset-free-all — 竞技场-重置-全部-免费

## 主张

在这台 Linux 机器上，Zig **0.17.0** 使用 `-Ofast` 时，ArenaAllocator.reset(.free_all) 每次迭代与 .retain_capacity 的对比显示了明显的前后实际时间差距。

## 如何测量

- 测试工具：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-arena-reset-free-all` 用例）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9轮的中位数**
- **之前：** `arena_reset_free_all`
- **之后：** `arena_reset_retain`
- 操作次数=50000
- 原始数据：[`zp-arena-reset-free-all.jsonl`](../zp-arena-reset-free-all.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~2.252 ms |
| Median after | ~0.7083 ms |
| **前/后比例** | **~3.18×** |

## 与 lint 的对应

`zperf-lint` `zp-arena-reset-free-all` / `arena-reset-free-all`。`rules.zig` 中的默认严重性是 **警告**；有关保留/升级，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在并且方向上**一致**。

## 结论

同意 ~3.18× — free_all 每次都会返回页面。

## 限制

当 RSS 必须释放时使用 free_all；保留以便快速重用。
