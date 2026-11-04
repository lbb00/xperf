# jp-data-copy-hot

## 主张

在循环中热使用 `data class.copy(...)` 会在每次迭代时分配一个新实例；局部变量可以避免这种情况。

## 如何测量

- 来源：`K14_LambdaCopyAlloc.jsonl`
- JDK **27 (27+35)**，Kotlin **2.4.21**，JVM 参数 `-XX:+UseCompactObjectHeaders`。Linux x64，负载 0.21。JDK 25 时间对大约是 1149×。
- **之前：** `simulateCopy_n1e4`
- **之后：** `simulateLocals_n1e4`

## 运行时（本证据文件）

| 字段 | 值 |
|-------|--------|
| When | 2026-10-23 |
| 之前 | **20884.1** ns_per_op, **240024.0** B/op |
| 之后 | **100.6** ns/次操作, **24.0** B/次操作 |
| **前后比率** | **约207.6×** 时间，**约10001×** 每操作字节 |

## Lint 映射 / 策略

策略**错误**。时间约为208×（原为~1149×）。分配仍约为10001× B/op。

## 限制

在这台机器上进行微基准测试；参见 `scripts/run-static-vs-hotspot.sh`。不要随意制定比率。语料库残差 ≠ 加速比。
