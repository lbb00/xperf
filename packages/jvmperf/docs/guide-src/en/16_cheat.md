## 16. Quick reference

| Goal | Prefer | Avoid or reconsider when |
|---|---|---|
| Store many integers | `int[]`, `IntArray`, fastutil, or androidx.collection | The collection is small or an API requires `List<Integer>`. |
| Map integer keys | `Int2ObjectOpenHashMap`, `IntObjectMap`, or Android `SparseArray` | Avoid `SparseArray` with thousands of entries and frequent inserts/removals. |
| Use enum keys or sets | `EnumMap` / `EnumSet` | A `null` key is required. |
| Store many boolean flags | Keep fields readable on individual objects; use `byte[]`, `long[]`, or `BitSet` for many instances (SoA). | There are few instances or flags are concurrently modified. |
| Reduce object headers | JDK 25 `-XX:+UseCompactObjectHeaders` (enabled by default in JDK 27). | Validate on the target runtime first. |
| Build strings in a loop | `StringBuilder(capacity)`, `buildString(capacity)`, or `String.join` | A single `+` expression needs no change. |
| Use regular expressions | `static final Pattern`; use `replace` for literal text. | One-off code. |
| Pre-size known collections | `new ArrayList<>(n)`, `HashMap.newHashMap(n)` | The element count is unknown. |
| Process numeric streams | `mapToInt(...).sum()`, `IntStream` | — |
| Process large Kotlin collection chains | `asSequence()` | The collection is small or the chain has one operation. |
| Use Kotlin value classes | Use them as their own type; store batches in primitive arrays. | Values are always nullable or generic; use the underlying primitive directly. |
| Optimize Kotlin higher-order functions | `inline` or a primitive-signature `fun interface` on hot paths. | The function body is large. |
| Initialize Kotlin values lazily on one thread | `lazy(LazyThreadSafetyMode.NONE)` | Multiple threads access the value. |
| Keep large data out of GC scans | FFM `Arena` and `MemorySegment` | Ordinary business objects. |
| Count under high contention | `LongAdder` | Contention is low. |
| Handle many blocking I/O tasks | One virtual thread per task | Work is CPU-bound. |
| Reuse expensive resources | Pool direct buffers, connections, or similar resources. | The object is small and cheap to allocate. |
| Reduce pause times | Generational ZGC or generational Shenandoah | Small heaps or batch jobs where G1/Parallel throughput is preferable. |
| Set a container heap | `-XX:MaxRAMPercentage=70~75` or explicit `-Xmx` | — |
| Improve startup | AOT cache (JDK 25 `-XX:AOTCacheOutput`), Android Baseline Profiles, or Native Image. | Native Image may not suit long-running services targeting peak throughput. |
| Measure performance | JMH `-prof gc`, JFR, async-profiler, JOL | Do not benchmark a loop with `System.nanoTime()`. |
| Check source patterns | jvmperf-lint plus PMD/Error Prone, detekt, and Android Lint as applicable. | Confirm static findings with a profiler. |

---

