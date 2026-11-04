# jp-baos-tobytearray-copy

## 主张

`ByteArrayOutputStream.toByteArray()` 份；在重复使用的 BAOS 上优先使用 `writeTo(out)`。

## 如何测量

- 来源：`J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**，JVM 参数 `-XX:+UseCompactObjectHeaders`
- **之前：** `toByteArray_4k`
- **之后：** `writeTo_reuse`

## 运行时（本证据文件）

| 字段 | 值 |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海 |
| 之前 | **13982.720** ns_per_op, **8224.210** B/op |
| 之后 | **140.556** ns/次操作, **0.002** B/次操作 |
| **前/后比例** | **~99.5×** |

## Lint 映射 / 策略

策略 **错误** (~99×)。

## 限制

在这台机器上进行微基准测试；参见 `scripts/run-static-vs-hotspot.sh`。不要随意制定比率。语料库残差 ≠ 加速比。
