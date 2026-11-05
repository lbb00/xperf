# jp-collection-chain

## 主张

Kotlin 迫切的 `map`/`filter` 链会分配完整的中间列表；当只使用前缀时，`asSequence()`（或命令式）可以避免这种情况。

## 如何测量

- 来源：`K13_SequenceAlloc.jsonl`
- JDK **27 (27+35)**，Kotlin **2.4.21**，JVM 参数 `-XX:+UseCompactObjectHeaders`。Linux x64，启动时负载 0.12。JDK 25 配对约为 391×。
- **之前:** `eagerChain_n1e5_take5`
- **之后:** `sequenceChain_n1e5_take5`

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| When | 2026-10-23 |
| before | **839101.9** ns_per_op, **2568512.0** B/op |
| after | **3170.2** ns_per_op, **232.0** B/op |
| **前/后比例** | **~264.7×** |
| 命令式 | **1178.0** 纳秒每操作, **80.0** 字节每操作, 大约 **712×** 对比 eager |

## Lint 映射 / 策略

相对于序列测得约265×；相对于命令式测得约712×。分配量保持不变，大约为2.6 MB，而不是232 B。在 `Rule.java` 中默认严重性为**关闭**（使用 `--enable` 运行它）。

## 限制

在这台机器上进行微基准测试；请参见 `scripts/run-static-vs-hotspot.sh`。不要随意编造比率。语料残差 ≠ 加速比。
