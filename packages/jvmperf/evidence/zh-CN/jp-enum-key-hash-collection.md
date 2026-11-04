# jp-enum-key-hash-collection

## 主张

对于小枚举键集合，使用带枚举键的 `HashMap`/`HashSet` 比 `EnumMap`/`EnumSet` 更慢且分配更多。

## 如何测量

- 来源：`J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**，JVM 参数 `-XX:+UseCompactObjectHeaders`
- **之前：** `hashMap_enumKey`
- **之后：** `enumMap`

## 运行时（本证据文件）

| 字段 | 值 |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海 |
| 之前 | **660.673** ns/次操作, **192.010** B/次操作 |
| 之后 | **56.779** ns/次操作, **0.001** B/次操作 |
| **前/后比例** | **~11.6×** |

## Lint 映射 / 策略

策略 **错误** (~11.6× 时间；HashMap 也 ~192 B/操作 vs ~0)。

## 限制

在这台机器上进行微基准测试；参见 `scripts/run-static-vs-hotspot.sh`。不要编造比例。语料库残差 ≠ 加速比。
