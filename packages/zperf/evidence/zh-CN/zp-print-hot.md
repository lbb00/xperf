# zp-print-hot — 循环中打印

## 主张

在这台 Linux 机器上，Zig **0.17.0** 使用 `-Ofast` 时，循环中的 std.debug.print 与安静的计数器（相同操作）显示出明显的前后实际时间差距。

## 如何测量

- 测试框架：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-print-hot` 情况）
- 构建：`zig build-exe -Ofast` · 优化模式=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9 轮的中位数**
- **之前：** `debug_print_in_loop`
- **之后：** `quiet_counter`
- 操作次数=2000
- 原始数据：[`zp-print-hot.jsonl`](../zp-print-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~2.86 ms |
| Median after | ~4.5e-05 ms |
| **前/后比率** | **~6.36e+04×** |

## 与 lint 的对应

`zperf-lint` `zp-print-hot` / `print-in-loop`。`rules.zig` 中的默认严重性是 **关闭**（CLI 不会报告该规则）；有关保留/升级，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在并且在方向上 **一致**。

## 结论

同意 ~63566× — stderr 锁 + 格式；依赖环境，比如 jsperf 的 jp-console-hot。

## 限制

故意的诊断仍然存在；--strict-log-in-loop 用于标准日志。建议使用缓冲的 Io.Writer。
