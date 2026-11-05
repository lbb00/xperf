# zp-append-without-reserve — 不保留地追加

## 主张

arrayList. appind in round vs sureal Total Capacity + 附加能力在 Zig 下 **0.17.0** `-Ofast'在Linux 机器上显示一个清晰的壁点后缺口.

## 如何测量

- 测试工具：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-append-without-reserve` 的案例）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9轮的中位数**
- **之前：** `append_no_reserve`
- **之后：** `ensure_then_assume`
- 操作数=50000
- 原始数据：[ `zp-append-without-reserve.jsonl`](../zp-append-without-reserve.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~0.1308 ms |
| Median after | ~0.06291 ms |
| **前后比例** | **~2.08×** |

## 与 lint 的对应

`zperf-lint` `zp-append-without-reserve` / `append-without-reserve`。在 `rules.zig` 中的默认严重性为 **关闭**（CLI 不会报告此规则）；有关保留/升级的详情，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。已有证据并且方向上 **一致**。

## 结论

同意 ~2.08× 对于 N=50k 从空开始的增长。

## 限制

当 N 未知时，保留可能浪费；测试/竞技场路径被 lint 跳过。
