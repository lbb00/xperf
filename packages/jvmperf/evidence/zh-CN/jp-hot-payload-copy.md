# jp-hot-payload-copy

## 主张

热点路径 `new byte[header+payload]` + 每帧都进行 arraycopy 分配；在帧处理时重用缓冲区。

## 如何测量

- 来源：`J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**，JVM 参数 `-XX:+UseCompactObjectHeaders`
- **之前：** `newFrameEach_1k`
- **之后：** `reuseBuffer_1k`

## 运行时（本证据文件）

| 字段 | 值 |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海 |
| 之前 | **2655.939** ns_per_op, **1040.037** B/op |
| 之后 | **16.820** ns/次操作, **0.000** B/次操作 |
| **前/后比例** | **~158×** |

## Lint 映射 / 策略

策略 **错误** (~158×)。

## 限制

在这台机器上的微基准；参见 `scripts/run-static-vs-hotspot.sh`。不要编造比率。语料库残差 ≠ 加速比。
