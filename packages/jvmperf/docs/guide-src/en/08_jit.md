## 8. Off-heap memory and I/O

### 8.1 Foreign Function & Memory API: `MemorySegment` and `Arena`

The FFM API was finalized in JDK 22 (JEP 454). `MemoryLayout` describes structs explicitly, with no object headers and a controllable layout. `Arena` controls the lifetime:

| Arena | Release | Threads |
|---|---|---|
| `Arena.ofConfined()` | Immediately on `close()` (use try-with-resources) | Creating thread only |
| `Arena.ofShared()` | On `close()` | Multiple threads |
| `Arena.ofAuto()` | Reclaimed by GC | Multiple threads |
| `Arena.global()` | Never released | Multiple threads |

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

Use it for very large data sets (gigabytes) that should not be scanned by the GC, exchanging structs with native libraries, deterministic release, and memory-mapped files.

Avoid it for ordinary business objects. Off-heap data needs manual serialization, and each access has a bounds check (which the JIT can often remove). Errors become bounds exceptions instead of being managed by the GC. `--enable-native-access` is needed only when calling native functions (downcalls), not for memory access alone.

### 8.2 Direct `ByteBuffer`

This older API is limited by `-XX:MaxDirectMemorySize` (zero by default means the maximum heap size) and is indirectly freed by a `Cleaner` during GC. Allocation and release cost more than heap memory, so **reuse direct buffers** (see Chapter 10) instead of creating one per request. A `ByteBuffer` is limited to 2 GB because it uses `int` indexes; `MemorySegment` has no such limit.

### 8.3 I/O

- For text, use `Files.newBufferedWriter` and `newBufferedReader` (8 KiB buffers by default) instead of writing bytes or characters directly through `FileOutputStream`.
- For random access to large files, `FileChannel.map(mode, offset, size, arena)` (JDK 22+) returns a `MemorySegment` without the 2 GB limit.
- For network services with many blocking I/O tasks, virtual threads (Chapter 10) are often simpler than a hand-written NIO selector and fast enough.

**Evidence (local):** JMH 1.37 on JDK 25 (`J30_BufferedIo`) writes N short UTF-8 lines — `FileOutputStream` per-chunk vs `BufferedOutputStream(8192)` (`-prof gc`). JSONL: `research/bench-results/J30_BufferedIo.jsonl` (re-run before citing).

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

Sources: [JEP 454: FFM API](https://openjdk.org/jeps/454) · [`Arena`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/foreign/Arena.html) · [`FileChannel.map(…, Arena)`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/FileChannel.html) · [`ByteBuffer`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/ByteBuffer.html)

---

## 9. Help the JIT: escape analysis, inlining, intrinsics, and Vector API

### 9.1 Escape analysis and scalar replacement

C2 checks whether an object escapes a method (for example, by being stored in a field or array, returned, or passed to a method that is not inlined). A non-escaping object can be **scalar-replaced**: its fields become local variables and the object is never allocated on the heap.

**Measured locally** with `research/EaProbe.java`, which uses `ThreadMXBean.getThreadAllocatedBytes` to measure 1,000 iterations of `new Vec(...).plus(new Vec(1,1))`:

| Runtime options | Bytes allocated per call |
|---|---:|
| Defaults (`DoEscapeAnalysis` and `EliminateAllocations` enabled) | ≈ 0 |
| `-XX:-DoEscapeAnalysis` | ≈ 96,000 |
| `-XX:-DoEscapeAnalysis -XX:+UseCompactObjectHeaders` | ≈ 72,000 |

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

For escape-analysis-friendly code, keep methods small enough to inline, do not store short-lived objects in fields or collections, and avoid complex control-flow merges. Small arrays can also be scalar-replaced, up to a limit (64 elements on the measurement machine: `EliminateAllocationArraySizeLimit`). **Do not rely on this optimization:** escape analysis takes effect only after C2 compilation, not during interpretation or C1. Android ART uses different AOT/JIT optimizations.

**Evidence (correlate):** Static JP smells vs HotSpot wall-clock/B/op — `scripts/run-static-vs-hotspot.sh` output `research/benches/static-vs-hotspot.jsonl` (cases 4 EA, 6 Vector control; JP rules never observe C1/C2 or call-site type profile). Package gate: `docs/evidence-policy.md`.

### 9.2 Inlining and call-site shape

Default values on the measurement machine's JDK 25 (`research/jvm-flags-jdk25.txt`): `MaxInlineSize = 35` bytecode bytes for non-hot methods, `FreqInlineSize = 325` for hot methods, `MaxInlineLevel = 15`, `InlineSmallCode = 2500`, and `TypeProfileWidth = 2`.

- C2 can inline **monomorphic and bimorphic** call sites (one or two receiver types seen at runtime). With more than two types (megamorphic), it usually falls back to virtual or interface dispatch, preventing later optimizations such as escape analysis. Avoid mixing many implementations at one hot call site, such as calling `shape.area()` on a `List<Shape>` with a dozen implementations.
- `sealed` types with pattern-matching `switch` turn dispatch into type checks and work well when the implementation set is fixed. `final` offers HotSpot little extra optimization; class hierarchy analysis can already identify methods with no subclasses. `final` is mainly a design constraint.
- Inspect decisions with `-XX:+UnlockDiagnosticVMOptions -XX:+PrintInlining` or JITWatch.

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

### 9.3 Intrinsics

HotSpot intrinsics such as `Integer.bitCount`, `Long.numberOfTrailingZeros`, `Math.fma`, `System.arraycopy`, `Arrays.equals`/`mismatch`, `String.indexOf`, and CRC32 compile to specialized instruction sequences. **Prefer JDK methods over hand-written bit tricks intended to optimize them.**

### 9.4 Vector API (still incubating)

JDK 25 has the 10th incubator round (JEP 508); JDK 26 and 27 continue with rounds 11 and 12. The API is expected to move to preview after Valhalla value types do. Compilation and execution both require `--add-modules jdk.incubator.vector`, and the runtime prints an incubator warning.

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

**Evidence (local):** JMH 1.37 on JDK 25 (`J28_VectorVsScalar`, `--add-modules jdk.incubator.vector`) — scalar float dot vs Vector API `SPECIES_PREFERRED` FMA over N floats (`-prof gc`). JSONL: `research/bench-results/J28_VectorVsScalar.jsonl` (re-run before citing; SuperWord may still help the scalar loop).

Avoid the API when production code cannot accept incubator changes, when C2's automatic vectorization (SuperWord) already handles a simple array loop, or on Android, where it is unavailable.

### 9.5 Exceptions

The most expensive part of creating an exception is `fillInStackTrace()`. Do not use exceptions for normal control flow, such as catching `NumberFormatException` to check whether text is numeric. If frequent exceptions are required, `RuntimeException(msg, cause, false, false)` creates one without a writable stack trace. HotSpot also omits stack traces by default for frequently thrown implicit exceptions such as NPE and bounds errors (`OmitStackTraceInFastThrow`), which is why production logs may contain only the exception name.

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

Sources: [Shipilёv: Scalar Replacement](https://shipilev.net/jvm/anatomy-quarks/18-scalar-replacement/) · [Shipilёv: Method Dispatch](https://shipilev.net/blog/2015/black-magic-method-dispatch/) · [JEP 508: Vector API, tenth incubator](https://openjdk.org/jeps/508) · [JEP 537](https://openjdk.org/jeps/537) · [`Throwable` constructors](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Throwable.html#%3Cinit%3E(java.lang.String,java.lang.Throwable,boolean,boolean)) · [JITWatch](https://github.com/AdoptOpenJDK/jitwatch)

---

## 10. Concurrency: false sharing, virtual threads, and object pools

### 10.1 False sharing and `@Contended`

When two threads frequently write fields on the same cache line (usually 64 bytes), each write invalidates the other's cache. HotSpot's `@jdk.internal.vm.annotation.Contended` pads fields; the measurement machine reported `ContendedPaddingWidth = 128` bytes. User code needs `--add-exports java.base/jdk.internal.vm.annotation=ALL-UNNAMED` at compile time and `-XX:-RestrictContended` at runtime (the default applies it only to JDK classes).

A simpler option for counters is `LongAdder`, whose internal `Cell` already uses `@Contended`. Alternatively, accumulate per thread and merge the results.

**Evidence (local):** JMH 1.37 on JDK 25 (`J22_FalseSharing`) — two threads increment distinct `volatile long` counters: adjacent (false sharing) vs `@Contended` (`-XX:-RestrictContended`) vs manual ~128 B padding vs shared `LongAdder` (throughput, ops/s). JSONL: `research/bench-results/J22_FalseSharing.jsonl` (re-run before citing).

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

Do not add padding without real write contention; it can waste 256 bytes per field. Confirm the issue with `perf c2c` or async-profiler first.

### 10.2 Virtual threads

Virtual threads were finalized in JDK 21 (JEP 444). They suit services with many tasks that spend most of their time blocked on I/O.

- Use one virtual thread per task; **do not pool virtual threads**. Use a `Semaphore` to limit access to downstream resources.
- Since JDK 24, `synchronized` no longer pins a virtual thread to its carrier (JEP 491). Native and foreign-function calls can still pin it.
- CPU-bound tasks do not benefit; use a platform-thread pool or `ForkJoinPool`.
- `ThreadLocal` memory adds up across millions of virtual threads. Replace `ThreadLocal` caches of large objects such as `SimpleDateFormat`; consider Scoped Values for shared data (finalized in JDK 25, JEP 506).
- **VT-safe pools (guide-first, no lint rule yet):** `ThreadLocal` buffer/`Recycler`-style pools without a virtual-thread branch inflate RSS under Loom (see Vert.x HybridJacksonPool). Prefer striped pools + cache-line padding, or size pools for carrier threads—not one fat TL slot per virtual thread. A lint rule stays deferred: high false-positive rate on legitimate TL caches.

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

**Evidence (local):** JMH 1.37 on JDK 25 (`J29_VirtualThreadsIo`) — N `LockSupport.parkNanos(100_000)` tasks joined via fixed platform pool vs one virtual thread per task (`-prof gc`). JSONL: `research/bench-results/J29_VirtualThreadsIo.jsonl` (re-run before citing; park stands in for blocked I/O).

### 10.3 Object pools: when to use them

Allocation in a thread-local allocation buffer (TLAB) is a pointer bump, and collecting short-lived young-generation objects is very cheap. Pooling small objects is often **slower**: they may be promoted to the old generation, need clearing or resetting, require synchronization, and can leak. Pool only genuinely expensive resources such as direct `ByteBuffer`s, large arrays, database connections, threads, or costly non-thread-safe objects such as `MessageDigest` and `Cipher`.

**Evidence (local):** JMH 1.37 on JDK 25 (`J24_PoolVsAlloc`) — batch of small escaping `Point` objects via TLAB `new` + `Blackhole` vs thread-local `ArrayDeque` pool reuse (`-prof gc`). JSONL: `research/bench-results/J24_PoolVsAlloc.jsonl` (re-run before citing). Pool cuts B/op near zero; wall time is often worse than TLAB for this size.

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

Sources: [JEP 142: `@Contended`](https://openjdk.org/jeps/142) · [`LongAdder`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/atomic/LongAdder.html) · [JEP 444: Virtual Threads](https://openjdk.org/jeps/444) · [JEP 491](https://openjdk.org/jeps/491) · [JEP 506: Scoped Values](https://openjdk.org/jeps/506) · [Oracle virtual-thread guide](https://docs.oracle.com/en/java/javase/25/core/virtual-threads.html)

---

## 11. Garbage collection

### 11.1 Choose a collector

| Collector | Option | Suitable for | Notes |
|---|---|---|---|
| G1 | Default (`-XX:+UseG1GC`) | Most services; balances throughput and pauses | JDK 26 reduces write-barrier synchronization (JEP 522); default everywhere in JDK 27 (JEP 523). |
| Parallel | `-XX:+UseParallelGC` | Batch jobs where throughput matters most | Pauses grow with heap size. |
| Serial | `-XX:+UseSerialGC` | One core, small containers, command-line tools | Lowest overhead. |
| ZGC | `-XX:+UseZGC` | Large heaps and sub-millisecond pauses | Generational by default since JDK 23; non-generational mode removed in JDK 24 (JEP 474/490). |
| Shenandoah | `-XX:+UseShenandoahGC` | Low-pause workloads | Generational mode finalized in JDK 25 (JEP 521, `-XX:ShenandoahGCMode=generational`). Not included in Oracle JDK; use an OpenJDK distribution such as Temurin. |
| Epsilon | `-XX:+UnlockExperimentalVMOptions -XX:+UseEpsilonGC` | Measuring allocation or very short-lived jobs | Does not reclaim memory (JEP 318). |

### 11.2 Heap size and containers

- The JVM reads cgroup limits in containers. Without `-Xmx`, the maximum heap defaults to 25% of available memory (`MaxRAMPercentage = 25` on the measurement machine), often too small in containers. Try `-XX:MaxRAMPercentage=70~75` or set `-Xmx`, leaving room for metaspace, thread stacks, direct memory, and code cache.
- For latency-sensitive services, set `-Xms` equal to `-Xmx` to avoid heap resizing and consider `-XX:+AlwaysPreTouch` to commit memory pages at startup.
- Keep the heap below the 32 GB compressed-reference boundary (Chapter 2).
- Compact object headers (opt-in on JDK 25 with `-XX:+UseCompactObjectHeaders`, enabled by default on JDK 27) can reduce heap use; test them on JDK 25.

### 11.3 Startup and warmup

AOT caching was introduced in JDK 24 (JEP 483). JDK 25 simplified its command line and added method profiles (JEP 514/515). Since JDK 26, AOT object caching works with any GC (JEP 516).

```sh
# JDK 25: train the application and write a cache
java -XX:AOTCacheOutput=app.aot -jar app.jar
# Production run
java -XX:AOTCache=app.aot -jar app.jar
```

### 11.4 Read GC logs

```sh
java -Xlog:gc*:file=gc.log:time,uptime,level,tags -jar app.jar
```

Do not call `System.gc()` in application code or pile on GC flags by guesswork. Start by choosing a heap size and collector, then use GC logs or JFR to justify further tuning.

Sources: [HotSpot GC tuning guide for JDK 25](https://docs.oracle.com/en/java/javase/25/gctuning/) · [JEP 474](https://openjdk.org/jeps/474) · [JEP 490](https://openjdk.org/jeps/490) · [JEP 521](https://openjdk.org/jeps/521) · [JEP 522](https://openjdk.org/jeps/522) · [JEP 523](https://openjdk.org/jeps/523) · [JEP 318: Epsilon](https://openjdk.org/jeps/318) · [JEP 483](https://openjdk.org/jeps/483) · [JEP 514](https://openjdk.org/jeps/514) · [JEP 515](https://openjdk.org/jeps/515) · [JEP 516](https://openjdk.org/jeps/516)

---

