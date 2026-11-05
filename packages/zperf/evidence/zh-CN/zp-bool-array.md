# zp-bool-array — 布尔数组

## 主张

在这台 Linux 机器上，[]bool count 与 bit_set.Static.count 在 Zig **0.17.0** 下使用 `-Ofast` 显示出明显的前后墙钟时间差。

## 如何测量

- 测试框架：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-bool-array` 的案例）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9 轮的中位数**
- **之前：** `bool_array_count`
- **之后：** `bitset_count`
- 操作数=524288
- 原始数据：[ `zp-bool-array.jsonl`](../zp-bool-array.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~0.08908 ms |
| Median after | ~0.002937 ms |
| **前/后比例** | **~30.3×** |

## 与 lint 的对应

`zperf-lint` `zp-bool-array` / `bool-array`。`rules.zig` 中的默认严重性是 **关闭**（CLI 不会报告该规则）；有关保留/升级，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在并且**方向上**一致。

## 结论

同意 ~30.3× 的 popcount 风格遍历（并且密度高 8 倍）。

## 限制

每个元素的可寻址性 / 并发位写入可能需要 []bool。
