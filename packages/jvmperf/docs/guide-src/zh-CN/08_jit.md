## 8. 堆外内存与 I/O

### 8.1 FFM API：`MemorySegment` + `Arena`

JDK 22 起正式（JEP 454）。用 `MemoryLayout` 显式描述结构体（没有对象头、布局完全可控），`Arena` 决定生命周期：

| Arena | 释放方式 | 线程 |
|---|---|---|
| `Arena.ofConfined()` | `close()` 时立即释放（try-with-resources） | 仅创建线程 |
| `Arena.ofShared()` | `close()` 时释放 | 多线程 |
| `Arena.ofAuto()` | 由 GC 回收 | 多线程 |
| `Arena.global()` | 永不释放 | 多线程 |

`examples/java/J06_OffHeapFfm.java`

```java
import java.lang.foreign.Arena;
import java.lang.foreign.MemoryLayout;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.StructLayout;
import java.lang.foreign.ValueLayout;
import java.lang.invoke.VarHandle;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/** Off-heap memory with the FFM API (final in JDK 22, JEP 454) and direct ByteBuffer. */
public class J06_OffHeapFfm {
    // struct Car { int id; byte flags; [3 bytes padding] } -- explicit layout with no object header.
    static final StructLayout CAR = MemoryLayout.structLayout(
            ValueLayout.JAVA_INT.withName("id"),
            ValueLayout.JAVA_BYTE.withName("flags"),
            MemoryLayout.paddingLayout(3));
    static final VarHandle ID = CAR.varHandle(MemoryLayout.PathElement.groupElement("id"));
    static final VarHandle FLAGS = CAR.varHandle(MemoryLayout.PathElement.groupElement("flags"));

    public static void main(String[] args) {
        check(CAR.byteSize() == 8, "layout size");
        try (Arena arena = Arena.ofConfined()) {               // Deterministic release when the try block ends.
            MemorySegment cars = arena.allocate(CAR, 1000);    // One contiguous block of 1,000 × 8 bytes.
            for (int i = 0; i < 1000; i++) {
                MemorySegment c = cars.asSlice(i * CAR.byteSize(), CAR);
                ID.set(c, 0L, i);
                FLAGS.set(c, 0L, (byte) 0b011);
            }
            MemorySegment c42 = cars.asSlice(42 * CAR.byteSize(), CAR);
            check((int) ID.get(c42, 0L) == 42 && (byte) FLAGS.get(c42, 0L) == 3, "segment");
            check(cars.byteSize() == 8000, "8000 bytes");
        }
        // Legacy API: GC reclaims direct ByteBuffers through Cleaner; capacity is limited by -XX:MaxDirectMemorySize.
        ByteBuffer bb = ByteBuffer.allocateDirect(8 * 1000).order(ByteOrder.nativeOrder());
        bb.putInt(42 * 8, 42).put(42 * 8 + 4, (byte) 3);
        check(bb.getInt(42 * 8) == 42, "direct buffer");
        System.out.println("J06 ok");
    }
    static void check(boolean ok, String what) { if (!ok) throw new AssertionError(what); }
}
```

适用：超大数据集（几 GB）不想让 GC 扫描；与本地库交换结构体；需要确定性释放；内存映射文件。

**不要用的时候**：普通业务对象。堆外数据要自己序列化/反序列化，每次访问都有边界检查（JIT 通常能消掉），出错时是越界异常而不是 GC 帮你兜底。`--enable-native-access` 只在调用本地函数（downcall）时需要，纯内存访问不需要。

### 8.2 direct `ByteBuffer`

老 API，容量受 `-XX:MaxDirectMemorySize` 限制（默认 0 表示与最大堆相同），由 `Cleaner` 随 GC 间接释放——分配/释放都比堆内贵，**适合长期复用**（见第 10 章对象池），不适合每个请求新建。单个 `ByteBuffer` 最大 2 GB（`int` 索引），`MemorySegment` 没有此限制。

### 8.3 I/O

- 文本：`Files.newBufferedWriter/newBufferedReader`（默认 8 KiB 缓冲），不要逐字节/逐字符直接写 `FileOutputStream`。
- 大文件随机读：`FileChannel.map(mode, offset, size, arena)`（JDK 22+）返回 `MemorySegment`，不受 2 GB 限制。
- 网络服务：大量阻塞 I/O 用虚拟线程（第 10 章）往往比手写 NIO 选择器更简单且足够快。

`examples/java/J12_Io.java`

```java
import java.io.BufferedWriter;
import java.io.IOException;
import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;

/** I/O: buffered writes, line-by-line reads, and mapping to an unrestricted-size MemorySegment. */
public class J12_Io {
    public static void main(String[] args) throws IOException {
        Path p = Files.createTempFile("jvmperf", ".txt");
        try (BufferedWriter w = Files.newBufferedWriter(p, StandardCharsets.UTF_8)) {  // 8 KiB buffer by default.
            for (int i = 0; i < 1000; i++) { w.write(Integer.toString(i)); w.newLine(); }
        }
        long lines;
        try (var s = Files.lines(p)) { lines = s.count(); }
        if (lines != 1000) throw new AssertionError();

        try (FileChannel ch = FileChannel.open(p, StandardOpenOption.READ); Arena arena = Arena.ofConfined()) {
            MemorySegment m = ch.map(FileChannel.MapMode.READ_ONLY, 0, ch.size(), arena);  // JDK 22+
            long newlines = 0;
            for (long i = 0; i < m.byteSize(); i++) if (m.get(ValueLayout.JAVA_BYTE, i) == '\n') newlines++;
            if (newlines != 1000) throw new AssertionError();
        }
        Files.delete(p);
        System.out.println("J12 ok");
    }
}
```

来源：[JEP 454 FFM API](https://openjdk.org/jeps/454) · [Arena](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/foreign/Arena.html) · [FileChannel.map(…, Arena)](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/FileChannel.html) · [ByteBuffer](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/ByteBuffer.html)

---

## 9. 让 JIT 帮你：逃逸分析、内联、intrinsic、Vector API

### 9.1 逃逸分析与标量替换

C2 会分析对象是否"逃出"方法（存进字段/数组、作为返回值、传给未内联的方法）。不逃逸的对象可以被**标量替换**——拆成几个局部变量，根本不在堆上分配。

**【本机实测】**（`research/EaProbe.java`，`ThreadMXBean.getThreadAllocatedBytes` 统计 1000 次循环中每次 `new Vec(...).plus(new Vec(1,1))` 的分配量）：

| 运行参数 | 每次调用分配 |
|---|---|
| 默认（`DoEscapeAnalysis`、`EliminateAllocations` 均开启） | ≈ 0 字节 |
| `-XX:-DoEscapeAnalysis` | ≈ 96,000 字节 |
| `-XX:-DoEscapeAnalysis -XX:+UseCompactObjectHeaders` | ≈ 72,000 字节 |

`examples/java/J08_EscapeAnalysis.java`

```java
/**
 * Escape analysis and scalar replacement: C2 may avoid heap allocation for small objects that do not escape.
 * Verify with -XX:-EliminateAllocations or JMH -prof gc; inspect gc.alloc.rate.norm.
 */
public class J08_EscapeAnalysis {
    record Vec(double x, double y) {
        Vec plus(Vec o) { return new Vec(x + o.x, y + o.y); }
        double len2() { return x * x + y * y; }
    }
    // Vec does not escape and its calls can inline, so C2 may replace it with two local doubles.
    static double sumLen2(double[] xs, double[] ys) {
        double s = 0;
        for (int i = 0; i < xs.length; i++) s += new Vec(xs[i], ys[i]).plus(new Vec(1, 1)).len2();
        return s;
    }
    static Vec last;                          // Storing into a static field makes the object escape.
    static void escapes(double x) { last = new Vec(x, x); }

    public static void main(String[] args) {
        double[] xs = {0, 1, 2}, ys = {0, 1, 2};
        if (sumLen2(xs, ys) != 2 + 8 + 18) throw new AssertionError();
        escapes(1);
        System.out.println("J08 ok");
    }
}
```

写出 EA 友好代码的要点：小方法（能被内联）、对象不存入字段/集合、不跨越 `synchronized` 以外的复杂控制流合并点。小数组同样可以被标量替换，但有上限（本机 `EliminateAllocationArraySizeLimit = 64` 个元素）。**不要依赖它**：EA 只在 C2 编译后生效，解释执行与 C1 阶段照样分配；Android ART 的 AOT/JIT 编译器做的优化不同。

### 9.2 内联与调用点形态

本机 JDK 25 默认值（`research/jvm-flags-jdk25.txt`）：`MaxInlineSize = 35`（字节码字节，非热点方法）、`FreqInlineSize = 325`（热点方法）、`MaxInlineLevel = 15`、`InlineSmallCode = 2500`、`TypeProfileWidth = 2`。

- **单态/双态**调用点（运行中只见过 1～2 个接收者类型）C2 可以内联；**超过 2 种（megamorphic）**通常退化为虚表/接口表调用，后续的逃逸分析等优化也随之失效。热路径上避免把很多不同实现混在同一个调用点（例如一个 `List<Shape>` 里有十几种实现都调用 `shape.area()`）。
- `sealed` + `switch` 模式匹配把分派变成类型判断，适合实现种类固定的场景。`final` 对 HotSpot JIT 几乎没有额外收益（类层次分析 CHA 已能识别没有子类的方法），它更多是设计上的约束。
- 观察：`-XX:+UnlockDiagnosticVMOptions -XX:+PrintInlining`，或 JITWatch。

`examples/java/J09_JitFriendly.java`

```java
/**
 * JIT-friendly code: sealed types, switch pattern matching, small methods, and intrinsics.
 * Inspect inlining with: java -XX:+UnlockDiagnosticVMOptions -XX:+PrintInlining
 */
public class J09_JitFriendly {
    sealed interface Shape permits Circle, Rect {}
    record Circle(double r) implements Shape {}
    record Rect(double w, double h) implements Shape {}

    static double area(Shape s) {
        return switch (s) {                       // Exhaustive switch; no virtual call.
            case Circle c -> Math.PI * c.r() * c.r();
            case Rect r -> r.w() * r.h();
        };
    }
    public static void main(String[] args) {
        Shape[] shapes = {new Circle(1), new Rect(2, 3)};
        double total = 0;
        for (Shape s : shapes) total += area(s);
        if (Math.abs(total - (Math.PI + 6)) > 1e-9) throw new AssertionError();
        // These HotSpot intrinsics compile to a small number of specialized instructions.
        if (Integer.bitCount(0b1011) != 3 || Long.numberOfTrailingZeros(8) != 3) throw new AssertionError();
        if (Math.fma(2.0, 3.0, 1.0) != 7.0) throw new AssertionError();
        if (java.util.Arrays.mismatch(new byte[]{1, 2, 3}, new byte[]{1, 2, 4}) != 2) throw new AssertionError();
        System.out.println("J09 ok");
    }
}
```

### 9.3 intrinsic

`Integer.bitCount`、`Long.numberOfTrailingZeros`、`Math.fma`、`System.arraycopy`、`Arrays.equals/mismatch`、`String.indexOf`、CRC32 等是 HotSpot intrinsic，编译成专门的指令序列。**优先用 JDK 方法，不要手写位技巧去"优化"它们**。

### 9.4 Vector API（仍在孵化）

JDK 25 是第 10 轮孵化（JEP 508），JDK 26/27 继续孵化（第 11/12 轮），要等 Valhalla 值类型进入预览后才会转为预览。编译和运行都需要 `--add-modules jdk.incubator.vector`，运行时会打印孵化模块警告。

`examples/java/J07_VectorApi.java`

```java
import jdk.incubator.vector.FloatVector;
import jdk.incubator.vector.VectorOperators;
import jdk.incubator.vector.VectorSpecies;

/**
 * Vector API (JDK 25, tenth incubator round, JEP 508). Compile and run with --add-modules jdk.incubator.vector.
 * javac --add-modules jdk.incubator.vector J07_VectorApi.java
 */
public class J07_VectorApi {
    static final VectorSpecies<Float> S = FloatVector.SPECIES_PREFERRED;   // Select a width supported by the CPU.

    static float dot(float[] a, float[] b) {
        var acc = FloatVector.zero(S);
        int i = 0, bound = S.loopBound(a.length);
        for (; i < bound; i += S.length()) {
            var va = FloatVector.fromArray(S, a, i);
            var vb = FloatVector.fromArray(S, b, i);
            acc = va.fma(vb, acc);
        }
        float sum = acc.reduceLanes(VectorOperators.ADD);
        for (; i < a.length; i++) sum += a[i] * b[i];                    // Handle the tail with scalar operations.
        return sum;
    }
    public static void main(String[] args) {
        float[] a = new float[1003], b = new float[1003];
        for (int i = 0; i < a.length; i++) { a[i] = 1; b[i] = 2; }
        if (dot(a, b) != 2006f) throw new AssertionError(dot(a, b));
        System.out.println("J07 ok, lanes=" + S.length());
    }
}
```

**不要用的时候**：生产代码不能接受孵化 API 的变动风险时；简单的数组循环 C2 的自动向量化（SuperWord）已经能处理；Android 上不可用。

### 9.5 异常

创建异常最贵的部分是 `fillInStackTrace()`。不要用异常做常规控制流（例如用 `NumberFormatException` 判断字符串是不是数字）。确实需要高频抛出时，可以用 `RuntimeException(msg, cause, false, false)` 构造不可写栈的异常。HotSpot 对频繁抛出的隐式异常（NPE、越界等）默认会省略栈（`OmitStackTraceInFastThrow = true`），这也是为什么线上日志里有时只看到异常名没有栈。

`examples/java/J14_Exceptions.java`

```java
/** Do not use exceptions for control flow; frequent exceptions can disable writable stack traces. */
public class J14_Exceptions {
    static final class ParseFailure extends RuntimeException {
        private static final long serialVersionUID = 1L;
        ParseFailure(String msg) { super(msg, null, false, false); }   // Skips stack capture; cheaper but harder to debug.
    }
    // Bad: use an exception to check whether a value is numeric.
    static boolean isIntSlow(String s) {
        try { Integer.parseInt(s); return true; } catch (NumberFormatException e) { return false; }
    }
    // Better: validate before parsing.
    static boolean isIntFast(String s) {
        if (s.isEmpty() || s.length() > 11) return false;          // "-2147483648" is 11 characters.
        int i = (s.charAt(0) == '-' || s.charAt(0) == '+') ? 1 : 0;
        if (i == s.length()) return false;
        for (; i < s.length(); i++) if (!Character.isDigit(s.charAt(i))) return false;
        try { Integer.parseInt(s); return true; } catch (NumberFormatException e) { return false; } // Only rare overflow cases reach the exception.
    }
    public static void main(String[] args) {
        for (String s : new String[]{"12", "-3", "x", "", "-", "99999999999", "-2147483648", "+5", "2147483648"})
            if (isIntSlow(s) != isIntFast(s)) throw new AssertionError(s);
        ParseFailure f = new ParseFailure("bad");
        if (f.getStackTrace().length != 0) throw new AssertionError();
        System.out.println("J14 ok");
    }
}
```

来源：[Shipilёv: JVM Anatomy Quark #18 Scalar Replacement](https://shipilev.net/jvm/anatomy-quarks/18-scalar-replacement/) · [Shipilёv: The Black Magic of (Java) Method Dispatch](https://shipilev.net/blog/2015/black-magic-method-dispatch/) · [JEP 508 Vector API (Tenth Incubator)](https://openjdk.org/jeps/508) · [JEP 537](https://openjdk.org/jeps/537) · [Throwable 构造器](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Throwable.html#%3Cinit%3E(java.lang.String,java.lang.Throwable,boolean,boolean)) · [JITWatch](https://github.com/AdoptOpenJDK/jitwatch)

---

## 10. 并发：伪共享、虚拟线程、对象池

### 10.1 伪共享与 `@Contended`

两个线程频繁写的字段落在同一个 cache line（通常 64 字节）上，会互相使对方的缓存失效。HotSpot 的 `@jdk.internal.vm.annotation.Contended` 会在字段前后填充（本机 `ContendedPaddingWidth = 128` 字节）。用户代码使用它需要：编译 `--add-exports java.base/jdk.internal.vm.annotation=ALL-UNNAMED`，运行 `-XX:-RestrictContended`（默认只对 JDK 内部类生效）。

更实用的做法：计数用 `LongAdder`（内部的 `Cell` 已经用 `@Contended`），每线程累积后再合并。

`examples/java/J10_FalseSharing.java`

```java
import java.util.concurrent.atomic.LongAdder;

/**
 * False sharing occurs when fields frequently written by different threads share a cache line.
 * - The JDK annotation @jdk.internal.vm.annotation.Contended requires the compile-time --add-exports flag
 *   and the runtime option -XX:-RestrictContended in user code.
 * - LongAdder is a ready-made option; its internal Cell counters use @Contended.
 * - Manual padding avoids JVM flags, but field layout is not guaranteed.
 */
public class J10_FalseSharing {
    static final class PaddedCounter {
        @jdk.internal.vm.annotation.Contended volatile long a;
        @jdk.internal.vm.annotation.Contended volatile long b;
    }
    public static void main(String[] args) throws Exception {
        LongAdder adder = new LongAdder();
        Thread[] ts = new Thread[4];
        for (int t = 0; t < ts.length; t++) {
            ts[t] = Thread.ofPlatform().start(() -> { for (int i = 0; i < 100_000; i++) adder.increment(); });
        }
        for (Thread t : ts) t.join();
        if (adder.sum() != 400_000) throw new AssertionError();
        PaddedCounter pc = new PaddedCounter();
        pc.a = 1; pc.b = 2;
        System.out.println("J10 ok");
    }
}
```

**不要用的时候**：没有真实的多线程写竞争时，填充只会浪费内存（每个字段多 256 字节）。先用 perf c2c / async-profiler 确认。

### 10.2 虚拟线程

JDK 21 正式（JEP 444）。适合"大量任务、大部分时间在阻塞 I/O"的服务。要点：

- 每个任务一个虚拟线程，**不要池化虚拟线程**；用 `Semaphore` 限制并发访问下游资源。
- JDK 24 起 `synchronized` 不再把虚拟线程钉在载体线程上（JEP 491）；调用本地方法/外部函数时仍会钉住。
- CPU 密集任务没有收益，用平台线程池 / `ForkJoinPool`。
- `ThreadLocal` 在百万虚拟线程下会放大内存，缓存大对象（如 `SimpleDateFormat`）的 `ThreadLocal` 写法要改掉；共享数据考虑 Scoped Values（JDK 25 正式，JEP 506）。

`examples/java/J11_VirtualThreads.java`

```java
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.IntStream;

/** Virtual threads (JDK 21, JEP 444) suit many blocking I/O tasks, not CPU-bound work. */
public class J11_VirtualThreads {
    public static void main(String[] args) {
        AtomicInteger done = new AtomicInteger();
        try (var exec = Executors.newVirtualThreadPerTaskExecutor()) {   // One virtual thread per task; do not pool them.
            IntStream.range(0, 10_000).forEach(i -> exec.submit(() -> {
                try { Thread.sleep(10); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
                done.incrementAndGet();
            }));
        } // close() waits for all tasks to finish.
        if (done.get() != 10_000) throw new AssertionError();
        System.out.println("J11 ok");
    }
}
```

### 10.3 对象池：何时用、何时不用

TLAB（线程本地分配缓冲）里的分配只是指针碰撞，年轻代回收短命对象几乎免费。池化小对象通常**更慢**：对象会被提升到老年代、需要清零/重置、需要并发控制、容易泄漏。只池化真正昂贵的东西：direct `ByteBuffer`、大数组、数据库连接、线程、`MessageDigest`/`Cipher` 之类初始化昂贵且非线程安全的对象。

`examples/java/J16_Pool.java`

```java
import java.nio.ByteBuffer;
import java.util.ArrayDeque;

/**
 * Pool only expensive resources such as direct ByteBuffers, large arrays, connections, and threads.
 * Pooling small objects is often slower: TLAB allocation is cheap, while pools add synchronization and leak risks.
 */
public class J16_Pool {
    static final class BufferPool {                       // Single-threaded; use one per thread or add locking for shared use.
        private final ArrayDeque<ByteBuffer> free = new ArrayDeque<>();
        private final int size;
        BufferPool(int size, int prealloc) {
            this.size = size;
            // jvmperf-lint: ignore jp-expensive-alloc-hot -- Pool is preallocated once during construction.
            for (int i = 0; i < prealloc; i++) free.push(ByteBuffer.allocateDirect(size));
        }
        ByteBuffer acquire() { ByteBuffer b = free.poll(); return b != null ? b.clear() : ByteBuffer.allocateDirect(size); }
        void release(ByteBuffer b) { free.push(b); }
    }
    public static void main(String[] args) {
        BufferPool pool = new BufferPool(64 * 1024, 4);
        ByteBuffer b = pool.acquire();
        b.putLong(42L);
        pool.release(b);
        if (pool.acquire() != b) throw new AssertionError();   // Reuses the same off-heap buffer.
        System.out.println("J16 ok");
    }
}
```

来源：[JEP 142 @Contended](https://openjdk.org/jeps/142) · [LongAdder](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/atomic/LongAdder.html) · [JEP 444 Virtual Threads](https://openjdk.org/jeps/444) · [JEP 491 Synchronize Virtual Threads without Pinning](https://openjdk.org/jeps/491) · [JEP 506 Scoped Values](https://openjdk.org/jeps/506) · [Oracle 虚拟线程指南](https://docs.oracle.com/en/java/javase/25/core/virtual-threads.html)

---

## 11. GC 选择与调优

### 11.1 选哪个 GC

| GC | 开关 | 适合 | 备注 |
|---|---|---|---|
| G1 | 默认（`-XX:+UseG1GC`） | 大多数服务，吞吐与停顿平衡 | JDK 26 起减少写屏障同步（JEP 522）；JDK 27 起在所有环境下都是默认（JEP 523） |
| Parallel | `-XX:+UseParallelGC` | 批处理、只看吞吐 | 停顿与堆大小成正比 |
| Serial | `-XX:+UseSerialGC` | 1 核 / 小内存容器、命令行工具 | 开销最小 |
| ZGC | `-XX:+UseZGC` | 大堆、亚毫秒级停顿 | JDK 23 起默认分代，JDK 24 移除非分代模式（JEP 474/490） |
| Shenandoah | `-XX:+UseShenandoahGC` | 低停顿 | JDK 25 分代模式正式（JEP 521，`-XX:ShenandoahGCMode=generational`）；Oracle JDK 不带，需 OpenJDK 发行版如 Temurin |
| Epsilon | `-XX:+UnlockExperimentalVMOptions -XX:+UseEpsilonGC` | 测试分配量、极短任务 | 不回收任何内存（JEP 318） |

### 11.2 堆大小与容器

- 容器里 JVM 会读取 cgroup 限制；不指定 `-Xmx` 时最大堆默认是可用内存的 25%（本机 `MaxRAMPercentage = 25`），在容器中通常偏小。常见做法：`-XX:MaxRAMPercentage=70~75`，或显式 `-Xmx`，并给元空间、线程栈、直接内存、代码缓存留余量。
- 低延迟服务：`-Xms` = `-Xmx` 避免堆伸缩，`-XX:+AlwaysPreTouch` 启动时提交内存页。
- 堆不要越过 32 GB 边界（压缩指针，第 2 章）。
- 紧凑对象头（JDK 25 `-XX:+UseCompactObjectHeaders`，JDK 27 默认开启）是"免费"的堆缩减，值得在 JDK 25 上测试打开。

### 11.3 启动与预热

AOT 缓存：JDK 24 引入（JEP 483），JDK 25 简化命令行并加入方法 profile（JEP 514/515），JDK 26 起任意 GC 都能用 AOT 对象缓存（JEP 516）。

```sh
# JDK 25：训练运行并直接生成缓存
java -XX:AOTCacheOutput=app.aot -jar app.jar
# 生产运行
java -XX:AOTCache=app.aot -jar app.jar
```

### 11.4 看 GC 日志

```sh
java -Xlog:gc*:file=gc.log:time,uptime,level,tags -jar app.jar
```

**不要做的事**：在代码里调用 `System.gc()`；凭感觉堆一长串 GC 参数（先只调堆大小和 GC 种类，用 GC 日志 / JFR 证明需要再细调）。

来源：[HotSpot GC 调优指南（JDK 25）](https://docs.oracle.com/en/java/javase/25/gctuning/) · [JEP 474](https://openjdk.org/jeps/474) · [JEP 490](https://openjdk.org/jeps/490) · [JEP 521](https://openjdk.org/jeps/521) · [JEP 522](https://openjdk.org/jeps/522) · [JEP 523](https://openjdk.org/jeps/523) · [JEP 318 Epsilon](https://openjdk.org/jeps/318) · [JEP 483](https://openjdk.org/jeps/483) · [JEP 514](https://openjdk.org/jeps/514) · [JEP 515](https://openjdk.org/jeps/515) · [JEP 516](https://openjdk.org/jeps/516)

---

