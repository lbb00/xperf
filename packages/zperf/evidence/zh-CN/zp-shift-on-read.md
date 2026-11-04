# zp-shift-on-read — 读取时转换

## 主张

在这台 Linux 机器上，Zig **0.17.0** 使用 `-Ofast` 时，copyForwards compact 在前缀之后消耗与 cursor head 的对比显示出明显的前后实时时钟差距。

## 如何测量

- 测试工具：`packages/zperf/examples/bench/evidence_fill.zig` （规则 `zp-shift-on-read` 的案例）
- 构建：`zig build-exe -Ofast` · 优化模式=`fast`
- 计时：`Io.Clock` 唤醒；热身=2；**9 轮的中位数**
- **之前：** `copy_forwards_consume`
- **之后：** `cursor_head`
- 操作次数=20000
- 原始数据：[`zp-shift-on-read.jsonl`](../zp-shift-on-read.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~0.2825 ms |
| Median after | ~0.01686 ms |
| **前后比例** | **~16.8×** |

## 与 lint 的对应

`zperf-lint` `zp-shift-on-read` / `shift-on-read`。`rules.zig` 中的默认严重性为 **警告**；有关保留/升级的信息，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在且在方向上 **一致**。

## 结论

在反复滑动剩余字节时，同意约16.8×。

## 限制

使用读取光标进行摊销；仅在需要时进行压缩。
