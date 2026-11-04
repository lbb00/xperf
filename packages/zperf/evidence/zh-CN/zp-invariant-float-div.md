# zp-不变浮点除法 — 不变浮点除法

## 主张

在这台 Linux 机器上，Zig **0.17.0** `-Ofast` 下，浮点数 / 循环不变量与乘以倒数的对比显示了明显的前后实际时间差异。

## 如何测量

- 测试框架：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-invariant-float-div` 情况）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9 轮的中位数**
- **之前：** `float_div_loop`
- **之后：** `mul_reciprocal`
- 操作次数=2000000
- 原始数据：[ `zp-invariant-float-div.jsonl`](../zp-invariant-float-div.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~2.504 ms |
| Median after | ~1.25 ms |
| **前/后比例** | **~2×** |

## 与 lint 的对应

`zperf-lint` `zp-invariant-float-div` / `invariant-float-div`。`rules.zig` 中的默认严重性是 **提示**；有关保留/升级，请参阅 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在并且在方向上**一致**。

## 结论

同意 ~2.00× 不使用快速数学（ReleaseFast 不会启用它）。

## 限制

舍入略有不同；请验证数值。
