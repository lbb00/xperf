# jp-boxed-primitive-collection — 装箱原始类型集合

## 主张

在 HotSpot 上，对 `List<Integer>` 或包装集合进行的热求和（或类似扫描）比对 `int[]`（或未装箱的流）进行相同操作要慢，主要是由于 **装箱、指针追踪和垃圾回收压力**——而不是因为静态分析检测到了 C2 失败。

## 如何测量

- 基准测试工具：通过 `scripts/run_jmh.sh J20_BoxingSum` 运行 `jmh-benches/.../J20_BoxingSum.java`
- 工作内容：处理 N=1_000_000 个元素；使用 JMH 1.37 的 avgt + `-prof gc`；`@Fork` 会附加 `-XX:+UseCompactObjectHeaders`
- **之前：** 对 `ArrayList<Integer>` 使用 `sumArrayList`
- **之后：** 对 `int[]` 使用 `sumIntArray`（也记录了：`sumIntStream`）
- 原始研究数据行：`research/bench-results/J20_BoxingSum.jsonl`
- 对应关联：`scripts/run-static-vs-hotspot.sh` 中的 `1_boxing_sum` 案例

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海 |
| JDK | **27 (27+35)** |
| JVM 参数 | `-XX:+UseCompactObjectHeaders`（JMH `@Fork` jvmArgsAppend） |
| before `sumArrayList[n=1000000]` | **478817.125 ns/op** |
| after `sumIntArray[n=1000000]` | **363120.071 ns/op** |
| **前/后比率** | **约1.32×** 在 n=1e6 时 |
| n=100000（相同的 JSONL） | 列表 **205276.327** 对比 `int[]` **27867.230** → **~7.37×** |
| vs `sumIntStream[n=1000000]` | 流 **618599.233 ns/op**，比列表慢 |

在空闲主机上（Temurin 21.0.13，负载 0.16，热度 5，中位数 9）稍后进行的方向检查不能替代此 JSONL。数值仍从 1000 开始。n=1e5，40 次循环：list 2.014 毫秒，`int[]` 0.238 毫秒，约 8.5 倍。n=1e6，8 次循环：list 6.504 毫秒，`int[]` 0.589 毫秒，约 11 倍。样本非常集中。JDK 27 n=1e6 ~1.32 倍在这里无法复现。默认保持 **关闭**。

## 与 lint 的对应

`jvmperf-lint` jp-boxed-primitive-collection（`boxed-primitive-collection`）标记 `List<Integer>`、`Map<Long,…>`、Kotlin `List<Int>` 等。默认严重性 **关闭**（使用 `--enable` 启用）；参见 [evidence-policy](../../docs/zh-CN/evidence-policy.md)。

## 限制

- 微基准测试，而不是应用程序配置文件；必须暴露装箱类型的 API 边界通常是虚假的“胜利”。
- 不要将 jp-boxed-primitive-collection 与 HotSpot 的去优化或“JIT 失败”等同。
- 语料库内部测试在测试/固定装置上仍然有浮点数——需要单独分类处理。
