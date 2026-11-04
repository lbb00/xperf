# jp-值类-装箱

## 主张

`@JvmInline` 值类在作为泛型/`Array`/`nullable` 元素使用时会进行装箱。在 JDK 27 / Kotlin 2.4.21 上，List 路径的时间大约是 `IntArray` 路径的 4.0 倍，分配大约是 5.0 倍。JDK 25 的时间对大约是 1.05 倍。

## 如何测量

- 来源：`K15_ValueClassBoxing.jsonl`
- JDK **27 (27+35)**，Kotlin **2.4.21**，JVM 参数 `-XX:+UseCompactObjectHeaders`。Linux x64，负载 0.78。
- **之前：** `sumBoxedList_UserId_n1e4`
- **之后：** `sumPrimitive_intArray_n1e4`

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| When | 2026-10-23 |
| before | **65983.793** ns_per_op, **200056.0** B/op |
| after | **16566.447** ns_per_op, **40032.453** B/op |
| **前后比率** | **约 3.98×** 时间，**约 5.0×** 每操作字节 |

## Lint 映射 / 策略

默认严重性 **提示**。List 与 `IntArray` 相比，大约慢 4.0 倍，分配内存约 5.0 倍。`Array<UserId>` 路径为 33385 ns/op 和 200032 B/op，大约是 `IntArray` 时间的 2.0 倍。

## 限制

在这台机器上进行微基准测试；请参见 `scripts/run-static-vs-hotspot.sh`。不要随意编造比率。语料残差 ≠ 加速比。
