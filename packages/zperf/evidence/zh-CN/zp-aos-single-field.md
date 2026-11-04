# zp-aos-single-field — aos-single-field

## 主张

在这台 Linux 机器上，AoS sum 一个字段与并行 []u32 SoA 在 Zig **0.17.0** `-Ofast` 下显示出明显的前后实时时钟差距。

## 如何测量

- 测试套件：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-aos-single-field` 的用例）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 激活；预热=2；**9 轮的中位数**
- **之前：** `aos_sum_hp`
- **之后：** `soa_sum_hp`
- 操作次数=4000000
- 原始数据：[ `zp-aos-single-field.jsonl`](../zp-aos-single-field.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~4.801 ms |
| Median after | ~0.731 ms |
| **前/后比例** | **~6.57×** |

## 与 lint 的对应

`zperf-lint` `zp-aos-single-field` / `aos-single-field`。`rules.zig` 中的默认严重性为 **关闭**（CLI 不会报告该规则）；有关保留/升级的信息，请参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。存在证据，并且在方向上 **一致**。

## 结论

当只有一个场热点（脂肪元素）时，同意约6.57×。

## 限制

其他循环可能会访问所有字段——lint 是一种审查提示。
