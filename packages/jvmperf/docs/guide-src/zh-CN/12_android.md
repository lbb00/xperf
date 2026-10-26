## 12. Android（ART）专项

### 12.1 ART 与 HotSpot 的差别

- 没有 C2，也没有 HotSpot 的逃逸分析/标量替换能力；ART 是"解释器 + JIT + 基于 profile 的 AOT（dex2oat）"混合模式。**在 Android 上"让 JIT 帮你消除分配"的假设不成立**，热路径（`onDraw`、滚动回调、动画帧）里的分配要真正避免。
- 引用本来就是 32 位；对象头 8 字节（`mirror::Object` 只有 class 指针 + monitor 两个 32 位字段），没有压缩指针或紧凑对象头开关。
- GC：Android 14 起（通过 ART mainline 模块更新）默认是并发标记整理（CMC，基于 userfaultfd）；Android 16 QPR2 起引入分代 CMC，优先回收新分配的对象。

### 12.2 容器：SparseArray / ArrayMap / androidx.collection

| 代替 | 用 | 原理 |
|---|---|---|
| `HashMap<Integer, V>` | `SparseArray<V>` | 有序 `int[]` 键 + `Object[]` 值，二分查找，无装箱无 Entry |
| `HashMap<Integer, Integer>` | `SparseIntArray` | 两个 `int[]` |
| `HashMap<Integer, Boolean>` | `SparseBooleanArray` | |
| `HashMap<Long, V>` | `LongSparseArray<V>` | |
| 小 `HashMap<K, V>` | `ArrayMap<K, V>` / `ArraySet` | 哈希数组 + 交错键值数组 |
| 跨平台 / 新代码 | `androidx.collection` 的 `IntObjectMap`、`MutableIntList`、`ScatterMap` | 开放寻址，通常比 `SparseArray` 更快 |

**不要用的时候**：`SparseArray`/`ArrayMap` 的查找是 O(log n)、插入是 O(n)（数组搬移），**元素上千或频繁插入删除时比 `HashMap` 慢**。官方文档也说明它们面向"最多几百项"的场景。

`examples/android/A01_AndroidCollections.java`

```java
import android.util.ArrayMap;
import android.util.Log;
import android.util.LongSparseArray;
import android.util.SparseArray;
import android.util.SparseBooleanArray;
import android.util.SparseIntArray;

/**
 * Android-only collections. Compile against android.jar stubs; this sample cannot run on a desktop JVM.
 * javac --release 17 -cp $ANDROID_HOME/platforms/android-34/android.jar A01_AndroidCollections.java
 */
public class A01_AndroidCollections {
    private static final String TAG = "Perf";

    static SparseArray<String> namesById(int[] ids, String[] names) {
        SparseArray<String> m = new SparseArray<>(ids.length);   // Replaces HashMap<Integer, String>; no boxing or Entry objects.
        for (int i = 0; i < ids.length; i++) m.put(ids[i], names[i]);
        return m;
    }
    static SparseIntArray histogram(int[] xs) {                  // Replaces HashMap<Integer, Integer>.
        SparseIntArray h = new SparseIntArray();
        for (int x : xs) h.put(x, h.get(x, 0) + 1);
        return h;
    }
    static ArrayMap<String, String> smallMap() {                 // Saves memory for small maps, but lookup uses binary search.
        ArrayMap<String, String> m = new ArrayMap<>(4);
        m.put("k", "v");
        return m;
    }
    static void process(int[] xs) {
        SparseBooleanArray seen = new SparseBooleanArray();
        LongSparseArray<Object> byTs = new LongSparseArray<>();
        for (int x : xs) {
            seen.put(x, true);
            byTs.put(x * 1000L, null);
            // Check the log level before formatting, or move logging out of the loop.
            if (Log.isLoggable(TAG, Log.VERBOSE)) Log.v(TAG, "x=" + x);
        }
        Log.d(TAG, "processed " + xs.length);
    }
}
```

### 12.3 R8

AGP 8.0 起 R8 默认 full mode：删除未用代码、内联、类合并、优化。keep 规则要精确，**不要 `-keep class com.example.** { *; }`**，那会关掉几乎所有优化。`-assumenosideeffects` 可以在发布版删除日志调用（仅当参数表达式本身无副作用时安全）。

`examples/android/A03_proguard-rules.pro`

```proguard
# R8 full mode is the default since AGP 8.0. Keep only classes accessed through reflection or JNI.
# Avoid -keep class com.example.** { *; }; it prevents removal, inlining, and class merging.
-keep class com.example.app.jni.NativeBridge { native <methods>; }
-keepclassmembers class com.example.app.model.** {
    @com.squareup.moshi.Json <fields>;
}
# Remove verbose/debug log calls from release builds only when their arguments have no side effects.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
}
```

### 12.4 Baseline Profiles

把启动和关键路径上的类/方法列表随 APK/AAB 发布，安装时由 dex2oat 预先 AOT 编译，避免首次运行时解释执行 + JIT。通常用 Macrobenchmark 的 `BaselineProfileRule` 自动生成，放到 `src/main/baseline-prof.txt`（或用 Baseline Profile Gradle 插件）。

`examples/android/A02_baseline-prof.txt`

```text
# Baseline Profile 规则示例（通常由 Macrobenchmark 的 BaselineProfileRule 自动生成，放在 src/main/baseline-prof.txt）
# H = 热方法, S = 启动时调用, P = 启动后调用；L 开头的是类描述符
HSPLcom/example/app/MainActivity;->onCreate(Landroid/os/Bundle;)V
HSPLcom/example/app/feed/FeedRepository;->**(**)**
Lcom/example/app/feed/FeedItem;
```

### 12.5 日志与热路径

- `Log.d/v` 在发布版仍然会执行参数里的字符串拼接。循环里先 `if (Log.isLoggable(TAG, Log.VERBOSE))` 或 `BuildConfig.DEBUG` 判断，或用 R8 `-assumenosideeffects` 去掉。
- `onDraw`/`onMeasure`/`onLayout` 里不要 `new Paint()`/`new Rect()`（Android Lint `DrawAllocation`）。

来源：[ART 与 Dalvik](https://source.android.com/docs/core/runtime) · [ART mirror/object.h](https://android.googlesource.com/platform/art/+/refs/heads/main/runtime/mirror/object.h) · [Android 16 QPR2 发布说明（分代 CMC）](https://developer.android.com/about/versions/16/qpr2/release-notes) · [SparseArray](https://developer.android.com/reference/android/util/SparseArray) · [ArrayMap](https://developer.android.com/reference/android/util/ArrayMap) · [R8 / 缩减代码](https://developer.android.com/build/shrink-code) · [Baseline Profiles](https://developer.android.com/topic/performance/baselineprofiles/overview) · [Android Lint 检查列表](https://googlesamples.github.io/android-custom-lint-rules/checks/index.md.html)

---

## 13. GraalVM Native Image

把应用在构建期做封闭世界（closed-world）分析并 AOT 编译成本地可执行文件：启动快（毫秒级）、常驻内存小、没有 JIT 预热；代价是构建慢、峰值吞吐通常低于 HotSpot C2（Oracle GraalVM 的 PGO 可以缩小差距）、反射/动态代理/资源需要元数据配置。

- GC：默认 Serial GC（面向小堆、低占用，未指定时最大堆为物理内存的 80%）；`--gc=G1` 仅 Oracle GraalVM 且仅 Linux AMD64/AArch64；`--gc=epsilon` 用于极短任务。
- PGO：`--pgo-instrument` 构建 → 跑代表性负载 → `--pgo` 重新构建（Oracle GraalVM）。
- 版本：2025 年 9 月起不再叫 "GraalVM for JDK N"，改为 "GraalVM 25.x" 并按月发布特性版本（2026-09-22 为 25.4.4.1.1）。

**不要用的时候**：长时间运行、追求峰值吞吐的服务（HotSpot + AOT 缓存可能是更好的折中）；大量依赖运行时字节码生成或反射且难以写配置的框架。

来源：[Native Image 内存管理（JDK 25）](https://www.graalvm.org/jdk25/reference-manual/native-image/optimizations-and-performance/MemoryManagement/) · [PGO 指南](https://www.graalvm.org/jdk25/reference-manual/native-image/guides/optimize-native-executable-with-pgo/) · [GraalVM 发布日历](https://www.graalvm.org/release-calendar/)

---

## 14. 度量工具：JMH、JFR、async-profiler、JOL

| 工具 | 回答的问题 | 最常用的方式 |
|---|---|---|
| [JMH](https://github.com/openjdk/jmh) | 这段代码多快？每次分配多少？ | `@Benchmark` + `-prof gc`，看 `gc.alloc.rate.norm` |
| [JFR](https://docs.oracle.com/en/java/javase/25/jfapi/) | 生产环境哪里在分配、哪里在等锁、GC 怎么样？ | `-XX:StartFlightRecording=duration=60s,filename=app.jfr`，`jfr print --events jdk.ObjectAllocationSample app.jfr`，或用 JDK Mission Control 打开 |
| [async-profiler](https://github.com/async-profiler/async-profiler)（当前 4.6） | CPU / 分配 / 锁火焰图，没有安全点偏差 | `asprof -e cpu -d 30 -f cpu.html <pid>`；`-e alloc` 看分配 |
| [JOL](https://github.com/openjdk/jol) | 这个对象 / 对象图到底多大？ | `ClassLayout.parseClass(X.class).toPrintable()`、`GraphLayout.parseInstance(obj).totalSize()` |
| `ThreadMXBean.getThreadAllocatedBytes` | 这段代码分配了多少字节（无需 agent） | 见 `research/EaProbe.java` |

JMH 模板（注意 `@Fork`、预热、返回值或 `Blackhole` 防止死代码消除）：

`examples/java/J19_JmhBench.java`

```java
import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.infra.Blackhole;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * JMH benchmark template. Compilation needs jmh-core and jmh-generator-annprocess to generate benchmark stubs.
 * After packaging with Maven or Gradle, run: java -jar benchmarks.jar J19_JmhBench -prof gc
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(value = 2, jvmArgsAppend = {"-XX:+UseCompactObjectHeaders"})
@State(Scope.Benchmark)
public class J19_JmhBench {
    @Param({"1000", "100000"}) int n;
    int[] prim;
    // jvmperf-lint: ignore jp-boxed-primitive-collection -- Intentional counterexample.
    List<Integer> boxed;

    @Setup public void setup() {
        prim = new int[n];
        boxed = new ArrayList<>(n);
        for (int i = 0; i < n; i++) { prim[i] = i; boxed.add(i); }
    }
    @Benchmark public long primitive() { long s = 0; for (int x : prim) s += x; return s; }   // Return the result to prevent dead-code elimination.
    @Benchmark public long boxedList() { long s = 0; for (Integer x : boxed) s += x; return s; }
    @Benchmark public void consume(Blackhole bh) { for (int x : prim) bh.consume(x); }
}
```

**常见错误**：在 `main` 里用 `System.nanoTime()` 测循环；只跑一次；不 fork；在笔记本上开着浏览器测；只看平均值不看分布。Android 上用 Jetpack Microbenchmark / Macrobenchmark 与 Android Studio Profiler / Perfetto。

来源：[JMH samples](https://github.com/openjdk/jmh/tree/master/jmh-samples/src/main/java/org/openjdk/jmh/samples) · [JEP 328 Flight Recorder](https://openjdk.org/jeps/328) · [JEP 509 JFR CPU-Time Profiling](https://openjdk.org/jeps/509) · [async-profiler](https://github.com/async-profiler/async-profiler) · [JOL](https://github.com/openjdk/jol) · [Jetpack Benchmark](https://developer.android.com/topic/performance/benchmarking/benchmarking-overview)

---

