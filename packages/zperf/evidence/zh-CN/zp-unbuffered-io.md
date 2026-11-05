# zp-无缓冲IO — 无缓冲IO

## 主张

在这台 Linux 机器上，使用 Zig **0.17.0** `-Ofast` 对 /dev/null 写入空缓冲区 (&{{}}) 与 4KiB 缓冲区显示出明显的前后实时时钟差异。

## 如何测量

- 测试框架：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-unbuffered-io` 情况）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9 轮的中位数**
- **之前：** `writer_empty_buf`
- **之后：** `writer_4kib_buf`
- 操作数=50000
- 原始数据：[ `zp-unbuffered-io.jsonl`](../zp-unbuffered-io.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~7.29 ms |
| Median after | ~0.1487 ms |
| **前/后比率** | **~49×** |

## 与 lint 的对应

`zperf-lint` `zp-unbuffered-io` / `unbuffered-io`。`rules.zig` 中的默认严重性为 **关闭**（CLI 不会报告此规则）；有关保留/升级的详细信息，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在并且在方向上 **一致**。

## 结论

同意 ~49.0× 墙；与指南第19页（~50×）相符。

## 限制

一次性写入 / readVec-writeVec / 被 lint 跳过的测试。
