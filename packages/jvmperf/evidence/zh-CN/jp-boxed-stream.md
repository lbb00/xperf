# jp-盒装流

## 主张

在 HotSpot 上，Boxed `Stream` reduce（`Integer::sum` / 类似）比 `mapToInt`/`mapToLong` 慢得多且分配更多内存。

## 如何测量

- 来源：`J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**，JVM 参数 `-XX:+UseCompactObjectHeaders`
- **之前：** `boxedReduce_n10k`
- **之后：** `mapToInt_n10k`

## 运行时（本证据文件）

| 字段 | 值 |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海 |
| 之前 | **745977.453** ns_per_op, **160178.813** B/op |
| 之后 | **20050.141** 每操作纳秒, **207.420** 每操作字节 |
| **前/后比例** | **~37.2×** |

## Lint 映射 / 策略

策略**错误**（墙钟时间约37×）。

## 限制

在这台机器上进行微基准测试；参见 `scripts/run-static-vs-hotspot.sh`。不要编造比例。语料库残差 ≠ 加速比。
