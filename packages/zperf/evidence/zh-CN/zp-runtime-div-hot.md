# zp-runtime-div-hot — 循环中的运行时 div

## 主张

在这台 Linux 机器上，Zig **0.17.0** 使用 `-Ofast` 时，i % runtime_pow2 与 i & (n-1) 显示出明显的前后墙钟时间差距。

## 如何测量

- 测试环境：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-runtime-div-hot` 的案例）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9轮的中位数**
- **之前：** `runtime_mod`
- **之后：** `bitmask`
- 操作次数=2000000
- 原始数据：[`zp-runtime-div-hot.jsonl`](../zp-runtime-div-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~3.777 ms |
| Median after | ~0.3242 ms |
| **前后比例** | **~11.6×** |

## 与 lint 的对应

`zperf-lint` `zp-runtime-div-hot` / `runtime-div-in-loop`。`rules.zig` 中的默认严重性为 **关闭**（CLI 不会报告该规则）；有关保留/升级的信息，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。存在证据，并且在方向上 **一致**。

## 结论

同意 ~11.6× 的二次方模数。

## 限制

Crypto/compiler_rt 路径被跳过；非 2 的幂需要其他重写。
