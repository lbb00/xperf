## 12. Android and ART

### 12.1 ART vs HotSpot

- ART has no C2 compiler or HotSpot-style escape analysis and scalar replacement. It combines interpretation, JIT compilation, and profile-guided AOT compilation (`dex2oat`). **Do not assume the JIT will remove allocations on Android**; avoid them in hot paths such as `onDraw`, scroll callbacks, and animation frames.
- References are already 32-bit and object headers are 8 bytes (`mirror::Object` has 32-bit class and monitor fields). ART has no compressed-reference or compact-header switch.
- Since Android 14, ART Mainline updates use Concurrent Mark Compact (CMC), based on `userfaultfd`, by default. Android 16 QPR2 adds generational CMC, which collects recently allocated objects first.

### 12.2 Collections: SparseArray, ArrayMap, and androidx.collection

| Replace | With | Implementation |
|---|---|---|
| `HashMap<Integer, V>` | `SparseArray<V>` | Sorted `int[]` keys and `Object[]` values; binary search, no boxing or entry objects. |
| `HashMap<Integer, Integer>` | `SparseIntArray` | Two `int[]` arrays. |
| `HashMap<Integer, Boolean>` | `SparseBooleanArray` | Primitive key and value arrays. |
| `HashMap<Long, V>` | `LongSparseArray<V>` | Primitive `long[]` keys. |
| Small `HashMap<K, V>` | `ArrayMap<K, V>` / `ArraySet` | Hash array and interleaved key/value array. |
| Cross-platform or new code | `androidx.collection` types such as `IntObjectMap`, `MutableIntList`, and `ScatterMap` | Open addressing; often faster than `SparseArray`. |

Avoid `SparseArray` and `ArrayMap` for thousands of entries or frequent insertions and removals. Lookup is O(log n), and insertion is O(n) because the arrays must shift. Android's documentation targets collections with at most a few hundred items.

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

R8 full mode is the default since AGP 8.0. It removes unused code, inlines methods, merges classes, and applies other optimizations. Keep rules should be narrow. **Avoid `-keep class com.example.** { *; }`**, which disables most optimizations. `-assumenosideeffects` can remove log calls from release builds, but only when evaluating their arguments has no side effects.

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

Ship a list of classes and methods used during startup and important flows with the APK/AAB. During installation, `dex2oat` compiles them ahead of time, reducing interpretation and JIT work on first use. Macrobenchmark's `BaselineProfileRule` can generate the list; place it in `src/main/baseline-prof.txt` or use the Baseline Profile Gradle plugin.

`examples/android/A02_baseline-prof.txt`

```text
# Baseline Profile 规则示例（通常由 Macrobenchmark 的 BaselineProfileRule 自动生成，放在 src/main/baseline-prof.txt）
# H = 热方法, S = 启动时调用, P = 启动后调用；L 开头的是类描述符
HSPLcom/example/app/MainActivity;->onCreate(Landroid/os/Bundle;)V
HSPLcom/example/app/feed/FeedRepository;->**(**)**
Lcom/example/app/feed/FeedItem;
```

### 12.5 Logging and hot paths

- In release builds, `Log.d` and `Log.v` still evaluate string concatenation in their arguments. Check `Log.isLoggable(TAG, Log.VERBOSE)` or `BuildConfig.DEBUG` first, or remove the calls with R8 `-assumenosideeffects`.
- Avoid `new Paint()` and `new Rect()` in `onDraw`, `onMeasure`, and `onLayout`; Android Lint's `DrawAllocation` check reports these allocations.

Sources: [ART and Dalvik](https://source.android.com/docs/core/runtime) · [ART `mirror/object.h`](https://android.googlesource.com/platform/art/+/refs/heads/main/runtime/mirror/object.h) · [Android 16 QPR2 release notes](https://developer.android.com/about/versions/16/qpr2/release-notes) · [`SparseArray`](https://developer.android.com/reference/android/util/SparseArray) · [`ArrayMap`](https://developer.android.com/reference/android/util/ArrayMap) · [R8 code shrinking](https://developer.android.com/build/shrink-code) · [Baseline Profiles](https://developer.android.com/topic/performance/baselineprofiles/overview) · [Android Lint checks](https://googlesamples.github.io/android-custom-lint-rules/checks/index.md.html)

---

## 13. GraalVM Native Image

Native Image performs closed-world analysis at build time and compiles an application to a native executable. Startup is fast (often milliseconds), resident memory is smaller, and there is no JIT warmup. Builds take longer, peak throughput is usually below HotSpot C2 (Oracle GraalVM PGO can narrow the gap), and reflection, dynamic proxies, and resources may need metadata.

- The default collector is Serial GC, intended for small heaps and low footprint. Without a limit, the maximum heap is 80% of physical memory. `--gc=G1` is available only in Oracle GraalVM on Linux AMD64/AArch64; `--gc=epsilon` suits very short jobs.
- For profile-guided optimization (Oracle GraalVM), build with `--pgo-instrument`, run a representative workload, then rebuild with `--pgo`.
- Since September 2025, releases are named `GraalVM 25.x` rather than "GraalVM for JDK N" and use monthly feature releases. Version 25.4.4.1.1 was released on 2026-09-22.

Avoid Native Image for long-running services that prioritize peak throughput; HotSpot with an AOT cache may be a better tradeoff. It also requires extra work for frameworks that rely heavily on runtime bytecode generation or reflection.

Sources: [Native Image memory management](https://www.graalvm.org/jdk25/reference-manual/native-image/optimizations-and-performance/MemoryManagement/) · [PGO guide](https://www.graalvm.org/jdk25/reference-manual/native-image/guides/optimize-native-executable-with-pgo/) · [GraalVM release calendar](https://www.graalvm.org/release-calendar/)

---

## 14. Measurement tools: JMH, JFR, async-profiler, and JOL

| Tool | Question | Common use |
|---|---|---|
| [JMH](https://github.com/openjdk/jmh) | How fast is this code? How much does each operation allocate? | `@Benchmark` with `-prof gc`; inspect `gc.alloc.rate.norm`. |
| [JFR](https://docs.oracle.com/en/java/javase/25/jfapi/) | Where does production allocate or wait on locks? What is GC doing? | `-XX:StartFlightRecording=duration=60s,filename=app.jfr`; use `jfr print --events jdk.ObjectAllocationSample app.jfr` or open it in JDK Mission Control. |
| [async-profiler](https://github.com/async-profiler/async-profiler) (4.6 at review time) | Where is CPU time, allocation, or lock contention? | `asprof -e cpu -d 30 -f cpu.html <pid>`; use `-e alloc` for allocations. |
| [JOL](https://github.com/openjdk/jol) | How large is an object or object graph? | `ClassLayout.parseClass(X.class).toPrintable()`; `GraphLayout.parseInstance(obj).totalSize()`. |
| `ThreadMXBean.getThreadAllocatedBytes` | How many bytes did this code allocate, without an agent? | See `research/EaProbe.java`. |

JMH template (use `@Fork`, warmup, and a return value or `Blackhole` to prevent dead-code elimination):

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

Common mistakes include timing a loop in `main` with `System.nanoTime()`, running once without forks, benchmarking on a busy laptop, or reporting only the average. On Android, use Jetpack Microbenchmark or Macrobenchmark with Android Studio Profiler or Perfetto.

Sources: [JMH samples](https://github.com/openjdk/jmh/tree/master/jmh-samples/src/main/java/org/openjdk/jmh/samples) · [JEP 328: Flight Recorder](https://openjdk.org/jeps/328) · [JEP 509: JFR CPU-time profiling](https://openjdk.org/jeps/509) · [async-profiler](https://github.com/async-profiler/async-profiler) · [JOL](https://github.com/openjdk/jol) · [Jetpack Benchmark](https://developer.android.com/topic/performance/benchmarking/benchmarking-overview)

---

