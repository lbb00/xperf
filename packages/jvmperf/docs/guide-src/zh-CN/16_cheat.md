## 16. 速查表

| 想做的事 | 做法 | 不要做的时候 |
|---|---|---|
| 存大量整数 | `int[]` / `IntArray` / fastutil / androidx.collection | 小集合、API 需要 `List<Integer>` |
| 整数键映射 | `Int2ObjectOpenHashMap`、`IntObjectMap`、Android `SparseArray` | 上千项且频繁增删时别用 `SparseArray` |
| 枚举键 / 枚举集合 | `EnumMap` / `EnumSet` | 需要 `null` 键 |
| 一堆布尔标志 | 对象内保持可读；**大量实例**时改成 `byte[]`/`long[]`/`BitSet`（SoA） | 实例少；标志需要并发修改 |
| 省对象头 | JDK 25 `-XX:+UseCompactObjectHeaders`（JDK 27 默认开） | 先在测试环境验证 |
| 循环里拼字符串 | `StringBuilder(cap)` / `buildString(cap)` / `String.join` | 单个表达式的 `+` 不用改 |
| 正则 | `static final Pattern`；字面替换用 `replace` | 一次性代码 |
| 已知元素个数 | `new ArrayList<>(n)`、`HashMap.newHashMap(n)` | 个数未知 |
| 数值流 | `mapToInt(...).sum()`、`IntStream` | — |
| Kotlin 多步链 + 大数据 | `asSequence()` | 小集合、单步 |
| Kotlin value class | 当作自身类型用；集合里用原始数组 | 总是可空/泛型时直接用底层类型 |
| Kotlin 高阶函数热路径 | `inline` 或原始类型 `fun interface` | 大函数 |
| Kotlin `by lazy` 单线程 | `lazy(LazyThreadSafetyMode.NONE)` | 多线程访问 |
| 大块数据不想让 GC 扫 | FFM `Arena` + `MemorySegment` | 普通业务对象 |
| 高并发计数 | `LongAdder` | 低竞争 |
| 大量阻塞 I/O 任务 | 虚拟线程，每任务一个 | CPU 密集任务 |
| 复用昂贵对象 | 池化 direct buffer / 连接 / `MessageDigest` | 小对象 |
| 低停顿 | ZGC（分代）/ 分代 Shenandoah | 小堆、批处理（用 G1/Parallel） |
| 容器 | `-XX:MaxRAMPercentage=70~75` 或显式 `-Xmx` | — |
| 启动快 | AOT 缓存（JDK 25 `-XX:AOTCacheOutput`）、Android Baseline Profiles、Native Image | 长跑服务追求峰值吞吐时慎用 Native Image |
| 测量 | JMH `-prof gc`、JFR、async-profiler、JOL | 不要用 `System.nanoTime()` 包循环当基准 |
| 自动检查 | jvmperf-lint + PMD/Error Prone + detekt + Android Lint | 静态提示都要用 profiler 确认 |

---

