# zp-map-put-without-ensure — map-put-without-ensure

## 主张

在这台 Linux 机器上，AutoHashMap.put 从空增长与在 Zig **0.17.0** `-Ofast` 下先 ensureTotalCapacity 再 put 显示了明显的前后墙钟时间差。

## 如何测量

- 测试工具：`packages/zperf/examples/bench/evidence_fill.zig`（规则 `zp-map-put-without-ensure` 的案例）
- 构建：`zig build-exe -Ofast` · optimize_mode=`fast`
- 计时：`Io.Clock` 唤醒；预热=2；**9 轮的中位数**
- **之前：** `map_put_grow`
- **之后：** `map_ensure_then_put`
- 操作次数=20000
- 原始数据：[`zp-map-put-without-ensure.jsonl`](../zp-map-put-without-ensure.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~0.8296 ms |
| Median after | ~0.3001 ms |
| **前/后比例** | **~2.76×** |

## 与 lint 的对应

`zperf-lint` `zp-map-put-without-ensure` / `map-put-without-ensure`。在 `rules.zig` 中的默认严重性为 **关闭**（CLI 不会报告此规则）；有关保留/升级，请参阅 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。证据存在并且方向上 **一致**。

## 结论

同意 ~2.76× 用于 N=20k 插入。

## 限制

未知最终大小：在批处理中确保未使用的容量。
