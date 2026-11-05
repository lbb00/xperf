# zp-固定大小分配-热点 — 循环中的固定大小分配

## 主张

在这台 Linux 机器上，GPA 分配+释放 256B 与预热缓冲池命中在 Zig **0.17.0** `-Ofast` 下显示出明显的前后实际时间差距。

## 如何测量

- 测试框架：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-fixed-size-alloc-hot` 用例）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9轮的中位数**
- **之前：** `fixed_alloc_free_loop`
- **之后：** `buffer_pool_hit`
- 操作次数=100000
- 原始数据：[ `zp-fixed-size-alloc-hot.jsonl`](../zp-fixed-size-alloc-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~2.001 ms |
| Median after | ~0.236 ms |
| **前/后比例** | **~8.48×** |

## 与 lint 的对应

`zperf-lint` `zp-fixed-size-alloc-hot` / `fixed-size-alloc-in-loop`。`rules.zig` 中的默认严重性为 **信息**；有关保留/升级，请参阅 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在并且在方向上**一致**。

## 结论

同意 ~8.5×（与 p20 池相比 GPA 一致）。

## 限制

池缺仍会影响GPA；规模类别的池很重要。
