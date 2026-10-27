# Java and Kotlin Performance Guide: Less Memory, More Throughput

> Target versions: **JDK 25** (Temurin 25.0.4.1 on the measurement machine) and **Kotlin 2.4** (kotlinc 2.4.21). Differences in JDK 21, 26, and 27 and in Android's ART runtime are called out where relevant.
> Last reviewed: 2026-10-21.
>
> - Every code sample comes from a standalone file under `examples/`. The Java samples were compiled with `javac --release 25` and run with self-checks; Kotlin samples were compiled with `kotlinc 2.4.21 -jvm-target 25` and run with self-checks. Android samples were compiled against `android-34/android.jar`. Logs are in `research/*-check.log`. Files under `research/` that this guide names (`*.txt`, `*.log`, `bench-results/`, `benches/`) are local run output and are not committed.
> - Values marked **Measured locally** were measured with JOL 0.17 on x86_64 Linux with 8 cores, JDK 25.0.4.1, G1, and compressed pointers enabled. Raw output is in `research/jol-jdk25.txt`, `research/jol-kotlin-jdk25.txt`, `research/ea-probe.txt`, and `research/jvm-flags-jdk25.txt`. Results vary across JDKs, pointer settings, and ART.
> - This guide does not invent speedup numbers. Use the JMH template in Chapter 14 to measure on your machine.
> - Each section links to its sources and explains when its recommendations do not apply.

## Contents

- [0. Version notes](#0-version-notes)
- [1. Method: estimate, then measure](#1-method-estimate-then-measure)
- [2. Object size: headers, compressed references, and compact headers](#2-object-size-headers-compressed-references-and-compact-headers)
- [3. Boxing and primitive collections](#3-boxing-and-primitive-collections)
- [4. Case study: memory used by a hybrid car](#4-case-study-memory-used-by-a-hybrid-car)
- [5. Data layout: primitive arrays, SoA, capacity, and EnumMap](#5-data-layout-primitive-arrays-soa-capacity-and-enummap)
- [6. Strings](#6-strings)
- [7. Kotlin-specific advice](#7-kotlin-specific-advice)
- [8. Off-heap memory and I/O](#8-off-heap-memory-and-io)
- [9. Helping the JIT: escape analysis, inlining, intrinsics, and Vector API](#9-helping-the-jit-escape-analysis-inlining-intrinsics-and-vector-api)
- [10. Concurrency: false sharing, virtual threads, and object pools](#10-concurrency-false-sharing-virtual-threads-and-object-pools)
- [11. Garbage collection](#11-garbage-collection)
- [12. Android and ART](#12-android-and-art)
- [13. GraalVM Native Image](#13-graalvm-native-image)
- [14. Measurement tools: JMH, JFR, async-profiler, and JOL](#14-measurement-tools-jmh-jfr-async-profiler-and-jol)
- [15. jvmperf-lint: find patterns automatically](#15-jvmperf-lint-find-patterns-automatically)
- [16. Quick reference](#16-quick-reference)
- [References](#references)

---

## 0. Version notes

| Version | Changes relevant to this guide |
|---|---|
| JDK 21 (previous LTS) | Virtual threads finalized (JEP 444); generational ZGC introduced (JEP 439, enabled with `-XX:+ZGenerational`). |
| JDK 22 | Foreign Function & Memory API (`MemorySegment`/`Arena`) finalized (JEP 454). |
| JDK 23 | Generational mode became the default for ZGC (JEP 474). |
| JDK 24 | Compact object headers preview (JEP 450); non-generational ZGC removed (JEP 490); `synchronized` no longer pins virtual threads (JEP 491); AOT class-loading cache (JEP 483). |
| **JDK 25 (LTS)** | Compact object headers finalized but **disabled by default** (JEP 519, `-XX:+UseCompactObjectHeaders`); generational Shenandoah finalized (JEP 521); Vector API incubator, 10th round (JEP 508); Stable Values preview (JEP 502); simplified AOT commands and method profiles (JEP 514/515); JFR CPU-time sampling experimental (JEP 509). |
| JDK 26 (2026-03) | G1 reduces synchronization to improve throughput (JEP 522); AOT object caching available with any GC (JEP 516); Stable Values renamed Lazy Constants (JEP 526, preview); Vector API incubator, 11th round. |
| JDK 27 (2026-09, non-LTS) | **Compact object headers enabled by default** (JEP 534); G1 is the default GC in all environments (JEP 523); Vector API incubator, 12th round (JEP 537, no API change). |
| JDK 28 (planned 2027-03) | Valhalla value classes (JEP 401) are expected to enter the mainline as a preview, according to InfoQ; the Vector API is expected to move from incubator to preview later. |
| Kotlin 2.0 | K2 compiler; lambdas use `invokedynamic` by default (`-Xlambdas=indy`). |
| Kotlin 2.4 (2026-06, current 2.4.21) | Context parameters and other features stabilized; Java 26 target supported; `-language-version 1.9` can no longer select K1. |
| Android | ART is not HotSpot: it has no C2 compiler or compressed-reference switch (references are already 32-bit), and uses 8-byte object headers. The default GC is Concurrent Mark Compact (CMC); Android 16 QPR2 adds generational CMC. See Chapter 12. |

Sources: [JDK 25](https://openjdk.org/projects/jdk/25/) · [JDK 26](https://openjdk.org/projects/jdk/26/) · [JDK 27](https://openjdk.org/projects/jdk/27/) · [JEP 534](https://openjdk.org/jeps/534) · [InfoQ: Java 27](https://www.infoq.com/news/2026/09/java27-released/) · [Kotlin 2.0](https://kotlinlang.org/docs/whatsnew20.html) · [Kotlin 2.4](https://kotlinlang.org/docs/whatsnew24.html) · [Kotlin release history](https://kotlinlang.org/docs/releases.html)

---

## 1. Method: estimate, then measure

1. **Estimate first.** JVM memory for an object is roughly its header, fields, and alignment padding, plus every object it references. Chapter 2 gives formulas and local measurements so you can estimate the cost of a million objects before changing code.
2. **Measure next.** Use JOL (`ClassLayout`/`GraphLayout`) for object sizes; JMH `-prof gc` and `gc.alloc.rate.norm`, or `ThreadMXBean.getThreadAllocatedBytes`, for allocation rates; async-profiler or JFR for CPU hotspots; and JMH for throughput and latency. Do not wrap a loop in `System.nanoTime()` and call it a benchmark: JIT warmup, dead-code elimination, and constant folding can invalidate the result.
3. **Optimize hotspots only.** Bit-packing a configuration object created a few dozen times is usually wasted effort. Replacing a `List<Integer>` with ten million entries by an `int[]` can make a large difference (see the measurements in Chapter 3).
4. **Measure again after the change.** Keep the benchmark and its correctness checks.

Chapter 14 explains how to use the measurement tools.

---

## 2. Object size: headers, compressed references, and compact headers

### 2.1 Object headers

Every HotSpot object has a header:

| Mode (64-bit JVM) | Mark word | Class pointer | Array length | Regular object header |
|---|---:|---:|---:|---:|
| Default through JDK 25, compressed class pointers | 8 bytes | 4 bytes | Arrays add 4 bytes | **12 bytes** |
| Compact headers with `-XX:+UseCompactObjectHeaders` (experimental in JDK 24, product in 25, default in 27) | 8 bytes (class pointer is encoded in the mark word) | — | Arrays add 4 bytes | **8 bytes** |

Object sizes are aligned to `ObjectAlignmentInBytes` (8 bytes by default). The smallest object is therefore 16 bytes by default; with compact headers, `new Object()` is only 8 bytes.

**Measured locally with JOL 0.17 on JDK 25.0.4.1:**

| Type | Default | `+UseCompactObjectHeaders` |
|---|---:|---:|
| `new Object()` | 16 | 8 |
| `Integer` / `Boolean` | 16 | 16 |
| `Long` | 24 | 16 |
| `class Point { int x, y; }` | 24 | 16 |
| `class { byte b; long l; int i; Object ref; boolean z; }` | 32 | 32 |
| `new int[0]` | 16 | 16 |
| `new int[1000]` / `new long[1000]` | 4016 / 8016 | 4016 / 8016 |
| `String` with 20 ASCII characters, including its `byte[]` | 64 | 56 |

Compact headers help most with small objects such as `Long` and a `Point` with two `int` fields. They do not change an object whose fields already fill the available padding, such as an `Integer` (12-byte header + 4-byte value). Array element storage is unchanged. JEP 534 estimates an average saving of 4 bytes per object.

```sh
# JDK 25: finalized, but disabled by default
java -XX:+UseCompactObjectHeaders -jar app.jar
# JDK 27: enabled by default; disable it if needed
java -XX:-UseCompactObjectHeaders -jar app.jar
```

Avoid enabling this when legacy native code or agents depend on object-header layout, or when your JDK 25 vendor build has a known issue. Compare heap use and pauses with JFR or GC logs before and after.

### 2.2 Compressed references (compressed oops)

By default, a 64-bit JVM compresses object references to 32 bits (`UseCompressedOops`; `PrintFlagsFinal` reported it as ergonomically enabled on the measurement machine). With 8-byte alignment, this addresses heaps of roughly 32 GB. Setting `-Xmx` above 32 GB can disable compressed references and make every reference 8 bytes; the larger heap can then hold fewer objects. For a much larger heap, either increase it substantially (for example, to 48 GB or more) or consider `-XX:ObjectAlignmentInBytes=16`. The latter expands the address range at the cost of more alignment waste per object.

### 2.3 Field layout

HotSpot can reorder fields: larger fields are placed first, then smaller fields fill gaps in the header and between fields. In the `Mixed` JOL output below, `int i` occupies offset 12, filling the space after the header. **Java field declaration order does not affect object size**, unlike a C struct. Size depends on field types and counts, alignment, and inheritance (parent fields are laid out first).

```text
Measured locally: JolSizes$Mixed (default object header)
OFF  SZ     TYPE DESCRIPTION
  0   8          (object header: mark)
  8   4          (object header: class)
 12   4      int Mixed.i
 16   8     long Mixed.l
 24   1     byte Mixed.b
 25   1  boolean Mixed.z
 26   2          (alignment/padding gap)
 28   4   Object Mixed.ref
Instance size: 32 bytes
```

### 2.4 Measure with JOL

All measurements in this chapter come from `research/JolSizes.java`; its header comments explain how to run it.

`research/JolSizes.java`

```java
import org.openjdk.jol.info.ClassLayout;
import org.openjdk.jol.info.GraphLayout;
import org.openjdk.jol.vm.VM;
import java.util.*;

/** 用 JOL 实测对象大小。运行：java -cp jol-core.jar:. [-XX:+UseCompactObjectHeaders] JolSizes */
public class JolSizes {
    enum Fuel { ELECTRIC, BENZINE, DIESEL }
    // 视频里的四步
    static final class HybridTwoInts { int electric; int benzine; }   // C: struct { int; int; } = 8 字节
    static final class FlagsInt { int flags; }                         // C: int flags = 4 字节
    static final class FlagsByte { byte flags; }                       // C: uint8_t 位域 = 1 字节
    static final class FlagsBools { boolean electric, benzine, diesel; }
    static final class FlagsEnumSet { final EnumSet<Fuel> fuels = EnumSet.noneOf(Fuel.class); }
    static final class Point { int x; int y; }
    static final class Mixed { byte b; long l; int i; Object ref; boolean z; }

    static void cls(Class<?> c) {
        System.out.printf("%-28s instance=%d%n", c.getSimpleName(), ClassLayout.parseClass(c).instanceSize());
    }
    static void graph(String what, Object o) {
        System.out.printf("%-40s total=%d bytes, objects=%d%n", what, GraphLayout.parseInstance(o).totalSize(),
                GraphLayout.parseInstance(o).totalCount());
    }

    public static void main(String[] args) {
        System.out.println("java.version=" + System.getProperty("java.version"));
        System.out.println(VM.current().details());
        System.out.println(ClassLayout.parseClass(Mixed.class).toPrintable());
        for (Class<?> c : List.of(Object.class, Integer.class, Long.class, Boolean.class, Point.class,
                HybridTwoInts.class, FlagsInt.class, FlagsByte.class, FlagsBools.class, FlagsEnumSet.class, Mixed.class)) cls(c);
        // EnumSet/EnumMap 引用的 Class 对象、枚举常量和 universe 数组是全类型共享的，这里只计每个实例独有的部分
        EnumSet<Fuel> es = EnumSet.of(Fuel.ELECTRIC, Fuel.BENZINE);
        long esSize = ClassLayout.parseInstance(es).instanceSize();
        System.out.printf("%-40s %s=%d bytes (独有部分)%n", "EnumSet.of(ELECTRIC,BENZINE)", es.getClass().getSimpleName(), esSize);
        System.out.printf("%-40s total=%d bytes (持有者 + RegularEnumSet)%n", "FlagsEnumSet 对象", ClassLayout.parseClass(FlagsEnumSet.class).instanceSize() + esSize);
        graph("BitSet(3)", new BitSet(3));
        graph("20 个 ASCII 字符的 String (Latin1)", new String("abcdefghijklmnopqrst"));
        graph("20 个汉字的 String (UTF16)", new String("一二三四五六七八九十一二三四五六七八九十"));
        graph("new int[0]", new int[0]);
        graph("new byte[1000]", new byte[1000]);
        graph("new int[1000]", new int[1000]);
        graph("new long[1000]", new long[1000]);
        HybridTwoInts[] cars = new HybridTwoInts[1000];
        for (int i = 0; i < cars.length; i++) cars[i] = new HybridTwoInts();
        graph("HybridTwoInts[1000] + 1000 objects", cars);
        FlagsByte[] fb = new FlagsByte[1000];
        for (int i = 0; i < fb.length; i++) fb[i] = new FlagsByte();
        graph("FlagsByte[1000] + 1000 objects", fb);
        graph("BitSet(3000) (1000 辆车 × 3 位)", new BitSet(3000));
        List<Integer> boxed = new ArrayList<>(1000);
        for (int i = 0; i < 1000; i++) boxed.add(i + 1000); // 超出 Integer 缓存，确保都是新对象
        graph("ArrayList<Integer> 1000 个 (>=1000)", boxed);
        int[] prim = new int[1000];
        graph("int[1000]", prim);
        Map<Integer, Integer> hm = new HashMap<>();
        for (int i = 0; i < 1000; i++) hm.put(i + 1000, i + 1000);
        graph("HashMap<Integer,Integer> 1000 项", hm);
        var fu = new it.unimi.dsi.fastutil.ints.Int2IntOpenHashMap();
        for (int i = 0; i < 1000; i++) fu.put(i + 1000, i + 1000);
        graph("fastutil Int2IntOpenHashMap 1000 项", fu);
        EnumMap<Fuel, Integer> em = new EnumMap<>(Fuel.class);
        System.out.printf("%-40s total=%d bytes (EnumMap 对象 + 长度 3 的 vals 数组，独有部分)%n", "EnumMap<Fuel,Integer>",
                ClassLayout.parseInstance(em).instanceSize() + ClassLayout.parseInstance(new Object[3]).instanceSize());
    }
}
```

JOL is a development-time measurement tool. Do not put it on a production code path. On JDK 25 it can emit warnings about `sun.misc.Unsafe` and dynamic agents. The local run used `-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading -Djol.magicFieldOffset=true --sun-misc-unsafe-memory-access=allow`.

Sources: [JEP 450](https://openjdk.org/jeps/450) · [JEP 519](https://openjdk.org/jeps/519) · [JEP 534](https://openjdk.org/jeps/534) · [JOL](https://github.com/openjdk/jol) · [Aleksey Shipilёv: JVM Anatomy Quarks](https://shipilev.net/jvm/anatomy-quarks/) · [OpenJDK Wiki: CompressedOops](https://wiki.openjdk.org/display/HotSpot/CompressedOops)

---

## 3. Boxing and primitive collections

### 3.1 The cost of boxing

Each element in a `List<Integer>` is a separate `Integer` object: a 16-byte object plus a 4-byte reference, as well as a pointer chase (and possible cache miss) and unboxing on reads. An `int[]` stores each value in 4 contiguous bytes.

**Measured locally: 1,000 values (all at least 1,000 to avoid the Integer cache):**

| Container | Total bytes (default) | Total bytes (compact headers) | Object count |
|---|---:|---:|---:|
| `int[1000]` | 4,016 | 4,016 | 1 |
| `ArrayList<Integer>` with reserved capacity | 20,040 | 20,040 | 1,002 |
| Kotlin `Array<Int>` | 20,016 | 20,016 | 1,001 |
| Kotlin `List<Int>` | 20,040 | 20,040 | 1,002 |
| `HashMap<Integer,Integer>` with 1,000 entries | 72,256 | 64,248 | 3,002 |
| fastutil `Int2IntOpenHashMap` with 1,000 entries | 16,496 | 16,480 | 3 |

The boxed list uses about five times as much memory as the primitive array. The boxed map uses about 4.4 times as much memory as the fastutil primitive map with default headers.

`examples/java/J01_Boxing.java`

```java
import java.util.ArrayList;
import java.util.List;
import java.util.stream.IntStream;

/** Boxing costs and pitfalls: List<Integer> vs int[], the Integer cache, and reference equality. */
public class J01_Boxing {
    // jvmperf-lint: ignore jp-boxed-primitive-collection -- Intentional counterexample.
    static long sumBoxed(List<Integer> xs) {
        long s = 0;
        for (Integer x : xs) s += x;          // Unboxes each value; throws NPE if x is null.
        return s;
    }
    static long sumPrimitive(int[] xs) {
        long s = 0;
        for (int x : xs) s += x;              // Contiguous storage, no pointer chasing; C2 may vectorize it.
        return s;
    }
    public static void main(String[] args) {
        int n = 10_000;
        // jvmperf-lint: ignore jp-boxed-primitive-collection -- Intentional counterexample.
        List<Integer> boxed = new ArrayList<>(n);
        int[] prim = new int[n];
        for (int i = 0; i < n; i++) { boxed.add(i); prim[i] = i; }
        check(sumBoxed(boxed) == sumPrimitive(prim), "sum");

        // Integer.valueOf caches -128..127; raise the upper bound with -XX:AutoBoxCacheMax.
        Integer a = 127, b = 127, c = 128, d = 128;
        check(a == b, "cached");                   // The same cached object.
        check(c.equals(d), "equals");              // Always use equals for wrapper values.
        // c == d is false with default settings; do not rely on reference identity.

        // Streams: mapToInt keeps primitive values; map(...).reduce(Integer::sum) boxes each step.
        long s1 = IntStream.range(0, n).asLongStream().sum();
        int s2 = boxed.stream().mapToInt(Integer::intValue).sum();
        check(s1 == sumPrimitive(prim) && s2 == (int) s1, "streams");
        System.out.println("J01 ok");
    }
    static void check(boolean ok, String what) { if (!ok) throw new AssertionError(what); }
}
```

Key points:

- `Integer.valueOf` caches values from −128 through 127 (the upper bound can be raised with `-XX:AutoBoxCacheMax`; it was 128 by default on the measurement machine). **Never compare wrapper objects with `==`.**
- For streams, use `mapToInt(...).sum()` instead of `map(...).reduce(0, Integer::sum)`, which boxes each intermediate value.
- C2 has `EliminateAutoBox` enabled by default on the measurement machine. It can remove some local boxing and unboxing, but cannot remove objects stored in a collection.

**Evidence (local):** JMH 1.37 on JDK 25 (`J20_BoxingSum`) sums N elements — `int[]` loop vs `ArrayList<Integer>` unbox loop vs `Arrays.stream(int[]).asLongStream().sum()` (`-prof gc`). JSONL: `research/bench-results/J20_BoxingSum.jsonl` (re-run before citing).

### 3.2 Primitive collection libraries

| Library | Characteristics | Status |
|---|---|---|
| [fastutil](https://fastutil.di.unimi.it/) | Broad coverage (`Int2IntOpenHashMap`, `IntArrayList`, big arrays). `fastutil-core` is a smaller package with only int/long/double collections; version 8.5.19 was about 6.6 MB locally. | Active |
| [Eclipse Collections](https://eclipse.dev/collections/) | Rich APIs such as `IntLists.mutable`, `IntIntHashMap`, and immutable collections; version 13.0.0 was measured locally. | Active |
| [Koloboke](https://github.com/leventov/Koloboke) | Once known for performance. | Last commit was in 2016; **avoid for new projects**. |
| [androidx.collection](https://developer.android.com/jetpack/androidx/releases/collection) | Kotlin Multiplatform; version 1.4+ includes `MutableIntList`, `MutableIntIntMap`, `IntObjectMap`, and more. It also works on the JVM; version 1.7.0 was measured locally. | Active |

`examples/java/J02_PrimitiveCollections.java`

```java
import it.unimi.dsi.fastutil.ints.Int2IntOpenHashMap;
import it.unimi.dsi.fastutil.ints.IntArrayList;
import org.eclipse.collections.api.list.primitive.MutableIntList;
import org.eclipse.collections.impl.factory.primitive.IntLists;
import org.eclipse.collections.impl.map.mutable.primitive.IntIntHashMap;

/** Primitive collections from fastutil and Eclipse Collections avoid boxing and per-entry Node objects. */
public class J02_PrimitiveCollections {
    public static void main(String[] args) {
        int n = 1000;
        Int2IntOpenHashMap counts = new Int2IntOpenHashMap(n);   // Reserve capacity.
        counts.defaultReturnValue(0);
        for (int i = 0; i < n; i++) counts.addTo(i % 10, 1);     // Increment in place without boxing.
        check(counts.get(3) == 100, "fastutil map");

        IntArrayList list = new IntArrayList(n);
        for (int i = 0; i < n; i++) list.add(i);
        check(list.getInt(999) == 999, "fastutil list");

        IntIntHashMap ec = new IntIntHashMap(n);
        for (int i = 0; i < n; i++) ec.addToValue(i % 10, 1);
        MutableIntList ecl = IntLists.mutable.withInitialCapacity(n);
        for (int i = 0; i < n; i++) ecl.add(i);
        check(ec.get(3) == 100 && ecl.sum() == 499500L, "eclipse collections");
        System.out.println("J02 ok");
    }
    static void check(boolean ok, String what) { if (!ok) throw new AssertionError(what); }
}
```

**Evidence (local):** JOL 0.17 GraphLayout on JDK 25 (`J31_PrimitiveMapsJol`) — `HashMap<Integer,Integer>` vs fastutil `Int2IntOpenHashMap` vs Eclipse `IntIntHashMap` vs androidx `MutableIntIntMap` for N∈{1000,100000} (keys outside the Integer cache); COH and default-header runs. JSONL: `research/bench-results/J31_PrimitiveMapsJol.jsonl` (re-run before citing).

Avoid these libraries for tiny collections (a few dozen elements) or where an API boundary requires `List<Integer>` or `Map<K,V>`; a large dependency may cost more than it saves. On Android, extra libraries also increase APK size. R8 can remove unused classes, but check the result.

Sources: [`Integer.valueOf`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Integer.html#valueOf(int)) · [fastutil](https://fastutil.di.unimi.it/) · [Eclipse Collections](https://eclipse.dev/collections/) · [Koloboke commit history](https://github.com/leventov/Koloboke/commits/master/)

---

## 4. Case study: memory used by a hybrid car

A popular C/C++ example models whether a car has an electric motor or a gasoline engine. Two `int` fields use 8 bytes; one `int` bit field uses 4; a `uint8_t` uses 1. The JVM behaves differently because **an object's size is determined by its header and 8-byte alignment**.

### 4.1 A single object: packing still leaves 16 bytes

**Measured locally with JOL 0.17 on JDK 25.0.4.1** (`research/jol-jdk25.txt`, `research/jol-kotlin-jdk25.txt`):

| Representation | Size in C | Default JVM | `+UseCompactObjectHeaders` |
|---|---:|---:|---:|
| `class { int electric; int benzine; }` | 8 | **24** | 16 |
| `class { int flags; }` | 4 | **16** | 16 |
| `class { byte flags; }` | 1 | **16** | 16 |
| `class { boolean electric, benzine, diesel; }` | 3 | **16** | 16 |
| `class { final EnumSet<Fuel> fuels; }` (holder plus `RegularEnumSet`) | — | **48** | 40 |
| Kotlin `data class HybridBools(Boolean, Boolean, Boolean)` | — | 16 | 16 |
| Kotlin `data class HybridInts(Int, Int)` | — | 24 | 16 |
| Kotlin `class Car(val fuels: FuelFlags)` (`FuelFlags` is a value class wrapping `Byte`) | — | 16 | 16 |

The default header is 12 bytes, so up to 4 bytes of fields still fit in a 16-byte object. Changing `int` to `byte` only creates more padding. Two `int` fields need 20 bytes before alignment, so the object occupies 24 bytes. Compact headers reduce it to 16 bytes; **that flag can save more than manually packing fields**. `EnumSet` is convenient, but it is a separate object containing a `long` and adds another object when stored as a field.

### 4.2 One thousand cars: avoid one object per car

| Storage for 1,000 cars | Default JVM | Compact headers | Notes |
|---|---:|---:|---|
| `HybridTwoInts[1000]` plus 1,000 objects | 28,016 | 20,016 | Measured locally |
| `FlagsByte[1000]` plus 1,000 objects | 20,016 | 20,016 | Measured locally; shrinking the field to one byte saves little |
| Kotlin `Array<FuelFlags>` with boxed value class values | 20,016 | 20,016 | Measured locally |
| `byte[1000]`, one byte per car | 1,016 | 1,016 | Measured locally; close to C's `uint8_t[1000]` |
| `BitSet(3000)`, three bits per car | 416 | 416 | Measured locally; `BitSet` plus `long[]` |
| `long[47]` (`PackedFleet`), three bits per car | 392 | — | Calculated: 16-byte array header plus 47 × 8 bytes |

On the JVM:

1. Packing flags inside one object rarely saves memory unless it crosses an 8-byte alignment boundary.
2. The large saving comes from replacing an **array of objects** with **primitive arrays** (Structure of Arrays; see Chapter 5). The example drops from 20 KB to 1 KB and removes 1,000 pointer chases.
3. Bit encodings (`byte` operations, `EnumSet`, `BitSet`) matter more at the array level. Prefer readable fields for individual objects.

Java version:

`examples/java/J03_Flags.java`

```java
import java.util.BitSet;
import java.util.EnumSet;

/** Flags using bit operations, EnumSet, and BitSet; this is the hybrid-car case study. */
public class J03_Flags {
    enum Fuel { ELECTRIC, BENZINE, DIESEL }

    // 1) One field per flag: three booleans.
    static final class CarBools { boolean electric, benzine, diesel; }

    // 2) Store three flags in one byte; Java requires explicit bit operations.
    static final class CarByte {
        static final int ELECTRIC = 1, BENZINE = 1 << 1, DIESEL = 1 << 2;
        byte flags;
        boolean has(int f) { return (flags & f) != 0; }
        void set(int f) { flags = (byte) (flags | f); }
        void clear(int f) { flags = (byte) (flags & ~f); }
    }

    // 3) Packing saves meaningful memory in arrays: one byte or three bits per car.
    static final class Fleet {
        final byte[] flags;               // Primitive array: one byte per car.
        Fleet(int n) { flags = new byte[n]; }
    }
    static final class PackedFleet {
        final long[] bits;                // Three densely packed bits per car.
        PackedFleet(int n) { bits = new long[(n * 3 + 63) >>> 6]; }
        void set(int car, int fuelBit) { int i = car * 3 + fuelBit; bits[i >>> 6] |= 1L << i; } // long shifts use the low six bits of the distance.
        boolean has(int car, int fuelBit) { int i = car * 3 + fuelBit; return (bits[i >>> 6] & (1L << i)) != 0; }
    }

    public static void main(String[] args) {
        CarByte hybrid = new CarByte();
        hybrid.set(CarByte.ELECTRIC | CarByte.BENZINE);
        check(hybrid.has(CarByte.ELECTRIC) && !hybrid.has(CarByte.DIESEL) && hybrid.flags == 0b011, "byte flags");

        EnumSet<Fuel> fuels = EnumSet.of(Fuel.ELECTRIC, Fuel.BENZINE);   // Up to 64 constants fit in one long.
        check(fuels.contains(Fuel.BENZINE) && fuels.size() == 2, "EnumSet");

        BitSet bs = new BitSet(3000);
        bs.set(5 * 3 + Fuel.BENZINE.ordinal());
        check(bs.get(16) && bs.cardinality() == 1, "BitSet");

        PackedFleet pf = new PackedFleet(1000);
        check(pf.bits.length == 47, "47 longs = 376 bytes of data"); // ceil(3000/64)
        pf.set(999, 2);
        check(pf.has(999, 2) && !pf.has(999, 1), "packed");
        Fleet f = new Fleet(1000);
        f.flags[0] = CarByte.ELECTRIC | CarByte.BENZINE;
        check(Integer.bitCount(f.flags[0]) == 2, "fleet");
        System.out.println("J03 ok");
    }
    static void check(boolean ok, String what) { if (!ok) throw new AssertionError(what); }
}
```

Kotlin version (`value class` gives a `Byte` a type and operations; the runtime field is still a byte):

`examples/kotlin/K05_Flags.kt`

```kotlin
// Kotlin version of the flag case study: boolean fields, bit operations, a value class, and arrays.
package k05

import java.util.EnumSet

enum class Fuel { ELECTRIC, BENZINE, DIESEL }

data class HybridBools(val electric: Boolean, val benzine: Boolean, val diesel: Boolean)

// The value class adds a type and operations to Byte; the runtime representation remains a byte.
@JvmInline
value class FuelFlags(val bits: Byte) {
    operator fun contains(f: Fuel): Boolean = (bits.toInt() and (1 shl f.ordinal)) != 0
    operator fun plus(f: Fuel): FuelFlags = FuelFlags((bits.toInt() or (1 shl f.ordinal)).toByte())
    operator fun minus(f: Fuel): FuelFlags = FuelFlags((bits.toInt() and (1 shl f.ordinal).inv()).toByte())
    companion object {
        val NONE = FuelFlags(0)
    }
}

class Car(var fuels: FuelFlags)      // The field is represented as a byte.

fun main() {
    val hybrid = FuelFlags.NONE + Fuel.ELECTRIC + Fuel.BENZINE
    check(Fuel.ELECTRIC in hybrid && Fuel.DIESEL !in hybrid)
    check(hybrid.bits.toInt() == 0b011)
    check((hybrid - Fuel.BENZINE).bits.toInt() == 0b001)
    check(Car::class.java.getDeclaredField("fuels").type == Byte::class.javaPrimitiveType)
    // Kotlin uses infix functions for bit operations: shl, shr, ushr, and, or, xor, inv.
    check((1 shl 2) or 1 == 5 && (0b110 and 0b011) == 0b010 && 5.inv() == -6)
    // For 1,000 cars, ByteArray uses one byte each; Array<FuelFlags> and List<FuelFlags> box every value.
    val fleet = ByteArray(1000)
    fleet[7] = hybrid.bits
    check(Fuel.BENZINE in FuelFlags(fleet[7]))
    val es: EnumSet<Fuel> = EnumSet.of(Fuel.ELECTRIC, Fuel.BENZINE)
    check(es.size == 2 && HybridBools(true, true, false).electric)
    println("K05 ok")
}
```

Avoid this approach when there are only a few dozen or hundred cars; arrays and bitmaps add complexity for little benefit. If flags are frequently updated by multiple threads, packing them into one `long` or `byte` can cause contention and require `AtomicLongArray` or `VarHandle` CAS. If callers need domain objects, keep that API and store the data in primitive arrays behind it (a flyweight view).

Sources: [JOL](https://github.com/openjdk/jol) · [EnumSet](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/EnumSet.html) · [BitSet](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/BitSet.html) · [Kotlin bitwise operations](https://kotlinlang.org/docs/numbers.html#bitwise-operations) · [Kotlin inline value classes](https://kotlinlang.org/docs/inline-classes.html)

---

## 5. Data layout: primitive arrays, SoA, capacity, and EnumMap

### 5.1 From AoS to SoA

An Array of Structures on the JVM means one reference array plus N scattered heap objects, each with its own header. Splitting fields into primitive arrays (Structure of Arrays) removes object headers and pointer chasing. It also improves cache locality when a loop reads one field and can make loop vectorization (C2 SuperWord) easier.

`examples/java/J04_SoA.java`

```java
/** Array of Structures vs Structure of Arrays: SoA is contiguous and header-free when scanning one field. */
public class J04_SoA {
    static final class Particle { double x, y, vx, vy; boolean alive; }   // AoS: each particle is a separate heap object.

    static final class Particles {                                       // SoA: one primitive array per field.
        final double[] x, y, vx, vy;
        final long[] alive;                                              // Store liveness flags out of band in a bitmap.
        int size;
        Particles(int cap) {
            x = new double[cap]; y = new double[cap]; vx = new double[cap]; vy = new double[cap];
            alive = new long[(cap + 63) >>> 6];
        }
        int add(double px, double py, double pvx, double pvy) {
            int i = size++;
            x[i] = px; y[i] = py; vx[i] = pvx; vy[i] = pvy; alive[i >>> 6] |= 1L << i;
            return i;
        }
        void step(double dt) {                                           // The hot loop touches only the needed arrays.
            for (int i = 0; i < size; i++) { x[i] += vx[i] * dt; y[i] += vy[i] * dt; }
        }
    }

    public static void main(String[] args) {
        Particles ps = new Particles(1024);
        for (int i = 0; i < 1000; i++) ps.add(i, 0, 1, 2);
        ps.step(0.5);
        if (ps.x[10] != 10.5 || ps.y[10] != 1.0) throw new AssertionError();
        Particle[] aos = new Particle[1000];
        for (int i = 0; i < aos.length; i++) { aos[i] = new Particle(); aos[i].x = i; aos[i].vx = 1; }
        for (Particle p : aos) p.x += p.vx * 0.5;
        if (aos[10].x != ps.x[10]) throw new AssertionError();
        System.out.println("J04 ok");
    }
}
```

**Evidence (local):** JMH 1.37 on JDK 25 (`jmh-benches` `J21_SoABandwidth`) steps N=1e6 particles — AoS `Particle[]` vs SoA parallel `double[]` fields (`-XX:+UseCompactObjectHeaders`, `-prof gc`). JSONL: `research/bench-results/J21_SoABandwidth.jsonl` (re-run before citing; machine metadata in-file).

Avoid SoA when objects must be passed around as a unit, stored in maps, or shared by many callers; when many fields are always accessed together; or when the data set is small. Removing one item also means updating several arrays consistently.

### 5.2 Reserve collection capacity

`ArrayList` grows by copying its backing array to about 1.5 times its previous size. `HashMap` doubles its table and rehashes entries. If the element count is known:

- Use `new ArrayList<>(n)`.
- On JDK 19 and later, use `HashMap.newHashMap(n)`, `HashSet.newHashSet(n)`, or `LinkedHashMap.newLinkedHashMap(n)`. The argument is the **number of elements** and the implementation accounts for the 0.75 load factor. In contrast, `new HashMap<>(n)` takes a **table capacity** and may still resize when adding n elements.
- In Kotlin, use `ArrayList<T>(n)`, `HashMap<K, V>(n)` (also a table capacity), `buildList(n) { }`, or `IntArray(n)`.

`examples/java/J13_Presize.java`

```java
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;

/** Reserve collection capacity and use EnumMap/EnumSet for enum keys. */
public class J13_Presize {
    enum Color { RED, GREEN, BLUE }
    public static void main(String[] args) {
        int n = 10_000;
        List<String> names = new ArrayList<>(n);                  // Avoid repeated growth and array copies.
        // jvmperf-lint: ignore jp-boxed-primitive-collection -- Intentional counterexample.
        Map<String, Integer> idx = HashMap.newHashMap(n);           // JDK 19+: reserve by element count, accounting for the load factor.
        HashSet<String> seen = HashSet.newHashSet(n);               // JDK 19+
        for (int i = 0; i < n; i++) { String s = "k" + i; names.add(s); idx.put(s, i); seen.add(s); }
        // Note: new HashMap<>(n) takes table capacity; inserting n elements may still resize it.
        EnumMap<Color, Integer> hits = new EnumMap<>(Color.class);  // Internally an array indexed by ordinal.
        hits.merge(Color.RED, 1, Integer::sum);
        EnumSet<Color> warm = EnumSet.of(Color.RED, Color.GREEN);
        if (idx.get("k42") != 42 || !warm.contains(Color.RED) || hits.get(Color.RED) != 1 || seen.size() != n)
            throw new AssertionError();
        System.out.println("J13 ok");
    }
}
```

**Evidence (local):** JMH 1.37 on JDK 25 (`J25_Presize`) fills an `ArrayList` with N boxed ints — grow-from-default vs `new ArrayList<>(n)`. JSONL: `research/bench-results/J25_Presize.jsonl` (re-run before citing). Boxing still dominates bytes/op; capacity mainly cuts backing-array copies.

### 5.3 Enum keys: EnumMap and EnumSet

`EnumMap` uses an array indexed by `ordinal()`. `EnumSet` uses a `long` bit vector for up to 64 constants. **Measured locally:** with three enum constants, `EnumMap` and its values array use 72 bytes total (64 with compact headers), without any `HashMap.Node` objects.

Avoid them when a `null` key is required (`EnumMap` and `EnumSet` do not allow one) or when keys can come from more than one enum type.

### 5.4 Bulk array operations

`System.arraycopy`, `Arrays.fill`, `Arrays.equals`, and `Arrays.mismatch` are HotSpot intrinsics. They are often faster and less error-prone than hand-written loops.

`examples/java/J18_Records.java`

```java
import java.util.Arrays;

/** Immutable values and bulk operations: record arrays vs primitive arrays; Arrays methods use intrinsics. */
public class J18_Records {
    record Sample(long ts, double value) {}
    public static void main(String[] args) {
        int n = 1000;
        long[] ts = new long[n];
        double[] vs = new double[n];
        Arrays.setAll(ts, i -> 1_000L * i);
        Arrays.fill(vs, 1.5);
        double sum = 0;
        for (double v : vs) sum += v;
        long[] copy = Arrays.copyOf(ts, n * 2);                // System.arraycopy intrinsic
        if (sum != 1500 || copy[999] != 999_000L || Arrays.binarySearch(ts, 5_000L) != 5) throw new AssertionError();
        Sample s = new Sample(ts[1], vs[1]);
        if (s.ts() != 1000) throw new AssertionError();
        System.out.println("J18 ok");
    }
}
```

Sources: [`HashMap.newHashMap` (JDK 19, JDK-8186958)](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/HashMap.html#newHashMap(int)) · [EnumMap](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/EnumMap.html) · [Arrays](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Arrays.html)

---

## 6. Strings

### 6.1 Compact Strings and deduplication

- Since JDK 9, `String` stores a `byte[]` and a coder (JEP 254). Latin-1 text uses one byte per character; other text uses two bytes per character in UTF-16. **Measured locally:** a 20-character ASCII string with its `byte[]` uses 64 bytes; a 20-character Chinese string uses 80. `-XX:-CompactStrings` disables this feature, which is enabled by default; there is rarely a reason to turn it off.
- `-XX:+UseStringDeduplication` lets the GC share backing arrays between strings with identical content; the `String` objects themselves remain separate. It began with G1 (JEP 192), and support was added to Serial, Parallel, and ZGC in JDK 18 (JDK-8272609 / 8267185 / 8267186). It was disabled by default on the measurement machine. It can help services that keep many duplicate strings alive, such as repeated values from deserialization.
- `String.intern()` returns a canonical instance from the string pool, so callers can compare references with `==` and keep one copy. Use it only when the value set is small, duplicates are common, and values live a long time. High-cardinality values can grow the native hash table behind the pool. A private `HashMap<String,String>` is often easier to control.

### 6.2 Concatenation

- `a + b + c` in one expression is fine. Since javac 9 it compiles to `invokedynamic` and `StringConcatFactory` (JEP 280). Kotlin string templates also use indy when targeting JVM 9 or later.
- **`s += x` in a loop is O(n²)** because every iteration copies the whole string built so far. Use a capacity-sized `StringBuilder`, `String.join`, `StringJoiner`, or `Collectors.joining`; in Kotlin use `buildString(capacity) { }` or `joinToString`.
- `StringBuffer` synchronizes every method. Use `StringBuilder` for single-threaded code.

`examples/java/J05_Strings.java`

```java
import java.util.List;
import java.util.StringJoiner;

/** Strings: reserve StringBuilder capacity, avoid += in loops, and use join or intern appropriately. */
public class J05_Strings {
    static String joinSlow(List<String> parts) {
        String s = "";
        // jvmperf-lint: ignore jp-string-concat-hot -- Intentional counterexample.
        for (String p : parts) s += p + ",";          // Creates and copies a new String each iteration: O(n²).
        return s;
    }
    static String joinFast(List<String> parts) {
        int cap = 0;
        for (String p : parts) cap += p.length() + 1;
        StringBuilder sb = new StringBuilder(cap);     // Allocate enough capacity once.
        for (String p : parts) sb.append(p).append(',');
        return sb.toString();
    }
    public static void main(String[] args) {
        List<String> parts = List.of("a", "bb", "ccc");
        check(joinSlow(parts).equals(joinFast(parts)), "join");
        check(String.join(",", parts).equals("a,bb,ccc"), "String.join");
        StringJoiner sj = new StringJoiner(",", "[", "]");
        parts.forEach(sj::add);
        check(sj.toString().equals("[a,bb,ccc]"), "joiner");
        // A single + expression is fine: javac 9+ uses invokedynamic and StringConcatFactory (JEP 280).
        String name = "x"; int n = 3;
        check((name + "=" + n).equals("x=3"), "indy concat");
        // Use intern for a small set of long-lived, repeated values; UseStringDeduplication shares backing arrays only.
        String k1 = new String("status-OK").intern(), k2 = "status-OK";
        check(k1 == k2, "intern");
        System.out.println("J05 ok");
    }
    static void check(boolean ok, String what) { if (!ok) throw new AssertionError(what); }
}
```

**Evidence (local):** JMH 1.37 on JDK 25 (`J23_StringConcat`) concatenates M short tokens — `s +=` in a loop vs `StringBuilder` (default capacity) vs capacity-presized builder (`-prof gc`). JSONL: `research/bench-results/J23_StringConcat.jsonl` (re-run before citing).

`examples/kotlin/K11_Strings.kt`

```kotlin
// Build strings with reserved capacity; avoid += concatenation in loops.
package k11

fun render(items: List<Pair<String, Int>>): String =
    buildString(items.size * 16) {                    // Estimate capacity to reduce growth.
        for ((k, v) in items) { append(k); append('='); append(v); append('\n') }
    }

fun renderSlow(items: List<Pair<String, Int>>): String {
    var s = ""
    // jvmperf-lint: ignore jp-string-concat-hot -- Intentional counterexample.
    for ((k, v) in items) s += "$k=$v\n"              // Copies the entire string on each iteration.
    return s
}

fun main() {
    val items = List(100) { "k$it" to it }
    check(render(items) == renderSlow(items))
    check(items.joinToString(",", limit = 2) { it.first } == "k0,k1,...")
    println("K11 ok")
}
```

### 6.3 Regular expressions

`String.split(regex)`, `replaceAll`, and `matches` compile a regular expression on each call. `split` has fast paths for a single non-metacharacter and for a backslash followed by a non-alphanumeric character. In hot code, compile a `Pattern` once and keep it in a `static final` field. For literal replacements, use `String.replace(CharSequence, CharSequence)`.

`examples/java/J15_Regex.java`

```java
import java.util.regex.Pattern;

/** Compile and reuse Pattern; String.split has a single-character fast path; replace(CharSequence) is literal. */
public class J15_Regex {
    private static final Pattern WS = Pattern.compile("\\s+");     // Compile once.

    static int countWordsSlow(String[] lines) {
        int n = 0;
        // jvmperf-lint: ignore jp-regex-hot -- Intentional counterexample.
        for (String l : lines) n += l.trim().split("\\s+").length;   // Compiles the regex on each call.
        return n;
    }
    static int countWordsFast(String[] lines) {
        int n = 0;
        for (String l : lines) n += WS.split(l.trim()).length;
        return n;
    }
    public static void main(String[] args) {
        String[] lines = {"a b  c", " d e "};
        if (countWordsSlow(lines) != countWordsFast(lines)) throw new AssertionError();
        // A single non-metacharacter such as "," takes String.split's fast path without regex compilation.
        if ("a,b,c".split(",").length != 3) throw new AssertionError();
        // replace(CharSequence, CharSequence) is literal; replaceAll treats its first argument as a regex.
        if (!"a.b.c".replace(".", "/").equals("a/b/c")) throw new AssertionError();
        System.out.println("J15 ok");
    }
}
```

**Evidence (local):** JMH 1.37 on JDK 25 (`J26_RegexCompile`) splits N lines on `\\s+` — `Pattern.compile` inside the loop vs `static final Pattern` (`-prof gc`). JSONL: `research/bench-results/J26_RegexCompile.jsonl` (re-run before citing).

For a one-off script or configuration parse that runs only at startup, do not complicate the code just to avoid compiling a regular expression once.

### 6.4 String.format

`String.format` and `formatted` parse the format string on every call and are much slower than appending to a `StringBuilder`. In hot code, use a builder or a precompiled `MessageFormat` or `DateTimeFormatter` (share only immutable, thread-safe instances; `DateTimeFormatter` is safe, `SimpleDateFormat` is not). For logging, use parameterized logging APIs and check the log level.

**Evidence (local):** JMH 1.37 on JDK 25 (`J27_FormatHot`) formats a fixed `LocalDateTime` to `yyyy-MM-dd'T'HH:mm:ss` — `String.format` vs hand `StringBuilder` pads vs precompiled `DateTimeFormatter` (`-prof gc`). JSONL: `research/bench-results/J27_FormatHot.jsonl` (re-run before citing).

Sources: [JEP 254: Compact Strings](https://openjdk.org/jeps/254) · [JEP 192: String Deduplication in G1](https://openjdk.org/jeps/192) · [JDK 18 release notes](https://www.oracle.com/java/technologies/javase/18-relnote-issues.html) · [JEP 280: Indify String Concatenation](https://openjdk.org/jeps/280) · [`String.split`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/String.html#split(java.lang.String)) · [Kotlin `-Xstring-concat`](https://kotlinlang.org/docs/compiler-reference.html#xstring-concat)

---

## 7. Kotlin-specific advice

Kotlin/JVM produces JVM bytecode, so the earlier chapters apply. This chapter covers allocations and boxing hidden behind Kotlin syntax.

### 7.1 `IntArray` vs `Array<Int>` vs `List<Int>`

| Kotlin type | JVM type | 1,000 values (each ≥1,000), measured locally |
|---|---|---:|
| `IntArray` | `int[]` | 4,016 bytes, 1 object |
| `Array<Int>` | `Integer[]` | 20,016 bytes, 1,001 objects |
| `List<Int>` | `ArrayList<Integer>` | 20,040 bytes, 1,002 objects |

`IntArray(n) { ... }`, `intArrayOf`, `for (x in intArray)`, `for (i in 0 until n)`, and `xs.indices` compile to ordinary integer loops. `(0 until n).map { }` creates a boxed `List<Int>`. `(1..10).forEach { }` creates an `IntRange` and iterator; a regular `for` loop does not.

`examples/kotlin/K01_Arrays.kt`

```kotlin
// IntArray maps to JVM int[]; Array<Int> and List<Int> store boxed Integer values.
package k01

fun sumIntArray(xs: IntArray): Long {
    var s = 0L
    for (x in xs) s += x            // Compiles to an indexed loop with no iterator or boxing.
    return s
}

// jvmperf-lint: ignore jp-boxed-primitive-collection -- Intentional counterexample.
fun sumList(xs: List<Int>): Long {
    var s = 0L
    for (x in xs) s += x            // Uses an iterator and unboxes each element.
    return s
}

fun main() {
    val n = 1000
    val prim = IntArray(n) { it }                 // int[]
    // jvmperf-lint: ignore jp-boxed-primitive-collection -- Intentional counterexample.
    val boxedArr: Array<Int> = Array(n) { it }    // Integer[]
    // jvmperf-lint: ignore jp-boxed-primitive-collection -- Intentional counterexample.
    val list: List<Int> = List(n) { it }          // ArrayList<Integer>
    check(prim.javaClass.name == "[I")
    check(boxedArr.javaClass.name == "[Ljava.lang.Integer;")
    check(sumIntArray(prim) == sumList(list))
    check(prim.sum() == boxedArr.sum())
    // Range loops also avoid allocation: 0 until n and xs.indices compile to integer loops.
    var s = 0
    for (i in prim.indices) s += prim[i]
    check(s == 499500)
    // (0 until n).map { } creates a boxed List<Int>; use IntArray(n) { } for primitive results.
    val squares = IntArray(n) { it * it }
    check(squares[3] == 9)
    println("K01 ok")
}
```

Use `List<Int>` when a collection API or library boundary requires it and the data set is small.

### 7.2 Boxing traps with value classes (`@JvmInline`)

`@JvmInline value class UserId(val raw: Int)` is represented as an `int` when used as its own type. These uses **box it into a `UserId` object**:

- As a generic argument: `List<UserId>`, `Map<UserId, …>`, or `T`.
- As a nullable value when its underlying type is primitive: `UserId?`.
- As an interface or `Any` value.

The example uses reflection to inspect field types: `Holder(val id: UserId)` has an `int` field, while `NullableHolder(val id: UserId?)` has a boxed `UserId` field. Use a sentinel instead of `null`, or store large batches in an `IntArray` and wrap values only when needed.

`examples/kotlin/K02_ValueClass.kt`

```kotlin
// A value class stays unboxed as its own type, but boxes as a generic, nullable, or interface value.
package k02

@JvmInline
value class UserId(val raw: Int)

class Holder(val id: UserId)            // The field is represented as int.
// jvmperf-lint: ignore jp-value-class-boxing -- Intentional counterexample.
class NullableHolder(val id: UserId?)   // Nullable use boxes the field as UserId.

// Use a sentinel instead of null to avoid boxing.
@JvmInline
value class OptUserId(val raw: Int) {
    val isNone: Boolean get() = raw == NONE
    companion object {
        const val NONE = -1
        val None = OptUserId(NONE)
    }
}
class OptHolder(val id: OptUserId)

fun main() {
    check(Holder::class.java.getDeclaredField("id").type == Int::class.javaPrimitiveType)
    check(NullableHolder::class.java.getDeclaredField("id").type == UserId::class.java)
    check(OptHolder::class.java.getDeclaredField("id").type == Int::class.javaPrimitiveType)
    // jvmperf-lint: ignore jp-value-class-boxing -- Intentional counterexample.
    val ids: List<UserId> = listOf(UserId(1), UserId(2))   // Generic elements are boxed UserId objects.
    check((ids[0] as Any).javaClass == UserId::class.java)
    // Store many IDs in IntArray and wrap them as UserId only when needed.
    val raw = intArrayOf(1, 2, 3)
    val first = UserId(raw[0])
    check(first == UserId(1) && OptHolder(OptUserId.None).id.isNone)
    println("K02 ok")
}
```

Value classes primarily provide type safety. If a value is always stored in collections or nullable fields, boxing can add an object; a plain `Int` with a clear name may be cheaper.

### 7.3 Inline functions, reified types, and lambda allocations

- An `inline` higher-order function expands the lambda body at the call site, with **no function object or boxing**. Standard-library functions such as `forEach`, `map`, `filter`, `sumOf`, and `repeat` are inline.
- A non-inline higher-order function receives a lambda object. A generic `(Int) -> Int` uses `Function1.invoke(Object)`, boxing its argument and result. On a hot path, use `inline` or a primitive signature such as `fun interface IntOp { fun apply(x: Int): Int }`.
- Since Kotlin 2.0, lambdas use `invokedynamic` (`LambdaMetafactory`) by default. A non-capturing lambda reuses an instance at the same call site; evaluating a capturing lambda creates a new object. The example checks this with `===`.
- `reified` lets an inline function access its type parameter directly, without a `Class` argument or reflection.

`examples/kotlin/K03_InlineLambdas.kt`

```kotlin
// Inline functions, reified types, and lambda allocations.
package k03

// inline expands the lambda at the call site, avoiding a function object and Int boxing.
inline fun repeatSum(n: Int, f: (Int) -> Int): Int {
    var s = 0
    for (i in 0 until n) s += f(i)
    return s
}

// A non-inline function receives a lambda object; Function1.invoke(Object) boxes the Int argument and result.
fun repeatSumBoxed(n: Int, f: (Int) -> Int): Int {
    var s = 0
    for (i in 0 until n) s += f(i)
    return s
}

// A primitive-signature fun interface avoids boxing through generic Function1.
fun interface IntOp { fun apply(x: Int): Int }
fun repeatSumPrim(n: Int, f: IntOp): Int {
    var s = 0
    for (i in 0 until n) s += f.apply(i)
    return s
}

// reified lets an inline function access its type parameter without a Class argument.
inline fun <reified T> List<Any>.countOf(): Int = count { it is T }

fun nonCapturing(): (Int) -> Int = { it + 1 }
fun capturing(k: Int): (Int) -> Int = { it + k }

fun main() {
    val k = 3
    check(repeatSum(10) { it * k } == repeatSumBoxed(10) { it * k })
    check(repeatSumPrim(10) { it * k } == 135)
    check(listOf<Any>(1, "a", 2).countOf<Int>() == 2)
    // Since Kotlin 2.0, lambdas use invokedynamic (LambdaMetafactory) by default.
    // A non-capturing lambda reuses an instance at one call site; a capturing lambda creates a new object each time.
    check(nonCapturing() === nonCapturing())
    check(capturing(1) !== capturing(1))
    println("K03 ok")
}
```

**Evidence (local):** ThreadMXBean allocated-bytes + wall time on JDK 25 (`K14_LambdaCopyAlloc`) — `inline` higher-order sum vs non-inline `Function1` boxing for N iterations (`-XX:+UseCompactObjectHeaders`). JSONL: `research/bench-results/K14_LambdaCopyAlloc.jsonl` (re-run before citing; rows `repeatSumInline` / `repeatSumBoxed`).

Avoid inlining large functions: their bytecode is copied to every call site, which can increase code size and exceed the JIT's inlining budget. `inline` works best for small higher-order functions.

### 7.4 Sequences vs collection operations

Each collection `map` or `filter` creates a complete intermediate `List`. `asSequence()` processes one element at a time and supports early termination. It is useful for multi-step chains over large data sets or chains that stop at `first` or `take`. It is often slower for small collections because each sequence step adds overhead. Avoid it for one operation or when random access is needed. `Sequence<Int>` still boxes elements; use a loop for numeric work.

`examples/kotlin/K04_Sequences.kt`

```kotlin
// Use asSequence() for multi-step chains over large data or with early termination; direct operations suit small collections.
package k04

fun main() {
    val data = List(100_000) { it }
    // Collection version: map creates a 100,000-element list, filter creates another, then take returns five.
    // jvmperf-lint: ignore jp-collection-chain -- Intentional counterexample.
    val eager = data.map { it * 2 }.filter { it % 3 == 0 }.take(5)
    // Sequence version: process one element at a time and stop after five matches, with no intermediate lists.
    var mapped = 0
    val lazy = data.asSequence().map { mapped++; it * 2 }.filter { it % 3 == 0 }.take(5).toList()
    check(eager == lazy)
    check(mapped < 20)              // Only the first few elements were processed.
    // Primitive operations such as IntArray.sumOf/fold are inline and do not box values.
    val arr = IntArray(1000) { it }
    check(arr.sumOf { it.toLong() } == 499500L)
    // Sequence<Int> still boxes elements; use a loop or IntStream for numeric pipelines.
    println("K04 ok")
}
```

**Evidence (local):** ThreadMXBean allocated-bytes + wall time on JDK 25 (`K13_SequenceAlloc`) — eager `map`/`filter`/`take` vs `asSequence()` vs imperative early-exit over N=100_000 (`-XX:+UseCompactObjectHeaders`). JSONL: `research/bench-results/K13_SequenceAlloc.jsonl` (re-run before citing).

### 7.5 `by lazy`

The default mode is `SYNCHRONIZED`: each property adds a `Lazy` object and a lambda, and the first access takes a lock. On a single thread (for example, the Android main thread), use `lazy(LazyThreadSafetyMode.NONE)`. Use `PUBLICATION` when initialization is idempotent. Avoid `by lazy` fields on classes with many instances; each instance adds two objects. A manual nullable cache can be smaller.

`examples/kotlin/K06_Lazy.kt`

```kotlin
// by lazy defaults to SYNCHRONIZED (with locking and an extra object); use NONE for single-threaded access.
package k06

class Config {
    // Accessed only on the main thread or another single thread:
    val parsed: Map<String, String> by lazy(LazyThreadSafetyMode.NONE) { mapOf("a" to "1") }
    // Multiple threads may access it and initialization is cheap and idempotent: PUBLICATION (may initialize more than once).
    val table: IntArray by lazy(LazyThreadSafetyMode.PUBLICATION) { IntArray(256) { it * it } }
    // Default mode: SYNCHRONIZED.
    // jvmperf-lint: ignore jp-lazy-default-mode -- Intentional counterexample.
    val heavy: String by lazy { "computed" }
}

// Each by lazy property adds a Lazy object and a lambda, which costs memory across many instances.
// For many instances, use a nullable field with a manual check or move the cache elsewhere.
class Row(private val raw: String) {
    private var cachedLen: Int = -1
    val len: Int get() { if (cachedLen < 0) cachedLen = raw.length; return cachedLen }
}

fun main() {
    val c = Config()
    check(c.parsed["a"] == "1" && c.table[3] == 9 && c.heavy == "computed")
    check(Row("abc").len == 3)
    println("K06 ok")
}
```

### 7.6 `const val`, `@JvmField`, and companion objects

- `const val` is a compile-time constant and is inlined at its use sites.
- A regular `val` in a `companion object` becomes a private static field and a `Companion.getXxx()` call. The JIT usually removes the call, but Java callers and startup-time interpreted code still use the getter. `@JvmField` exposes a field and removes the getter.
- These choices mainly affect API shape and cold-start behavior (more visibly on Android). They have little effect on steady-state performance; do not weaken encapsulation for them.

`examples/kotlin/K07_ConstJvmField.kt`

```kotlin
// const val and @JvmField change generated getters and companion-object indirection.
package k07

import java.lang.reflect.Modifier

class Limits {
    companion object {
        const val MAX = 1024                      // Compile-time constant, inlined at use sites.
        @JvmField val DEFAULT_NAMES = listOf("a")  // Public static final field on the outer class; no getter.
        val viaGetter = listOf("b")                // Private static field plus Companion.getViaGetter().
    }
}

object Registry {
    @JvmField val items = ArrayList<String>()     // @JvmField lets Java access Registry.items directly.
}

class Point(@JvmField val x: Int, @JvmField val y: Int)   // Java callers access the fields directly.

fun main() {
    val f = Limits::class.java.getDeclaredField("DEFAULT_NAMES")
    check(Modifier.isPublic(f.modifiers) && Modifier.isStatic(f.modifiers))
    check(!Modifier.isPublic(Limits::class.java.getDeclaredField("viaGetter").modifiers))
    check(Limits.MAX == 1024 && Point(1, 2).x == 1)
    Registry.items.add("x")
    println("K07 ok")
}
```

### 7.7 Data class `copy()`

Each `copy()` allocates a new object. Repeated copies in a hot loop can create many short-lived objects, and escape analysis may not remove them when objects survive across iterations. Accumulate values in locals and construct once at the end.

`examples/kotlin/K08_DataCopy.kt`

```kotlin
// Each data class copy() allocates an object; repeated copies in a hot loop create many short-lived objects.
package k08

data class State(val x: Int, val y: Int, val steps: Int)

fun simulateCopy(n: Int): State {
    var s = State(0, 0, 0)
    // jvmperf-lint: ignore jp-data-copy-hot -- Intentional counterexample.
    repeat(n) { s = s.copy(x = s.x + 1, steps = s.steps + 1) }   // n allocations; escape analysis may not remove them.
    return s
}

// On a hot path, accumulate in locals (or a mutable helper) and construct the immutable result once.
fun simulateLocals(n: Int): State {
    var x = 0; var steps = 0
    repeat(n) { x++; steps++ }
    return State(x, 0, steps)
}

fun main() {
    check(simulateCopy(1000) == simulateLocals(1000))
    println("K08 ok")
}
```

**Evidence (local):** ThreadMXBean allocated-bytes + wall time on JDK 25 (`K14_LambdaCopyAlloc`) — data-class `copy()` in a loop vs locals then one construct (`-XX:+UseCompactObjectHeaders`). JSONL: `research/bench-results/K14_LambdaCopyAlloc.jsonl` (re-run before citing; rows `simulateCopy` / `simulateLocals`).

Immutability is often worth a few allocations. Change it only when a profiler identifies allocation as a hotspot.

### 7.8 `vararg` and the spread operator `*`

`f(*array)` **copies** the array (the example checks this with `!==`). `f(1, 2, 3)` creates a new array on each call. On hot paths, provide an overload that accepts `IntArray` directly.

`examples/kotlin/K09_Varargs.kt`

```kotlin
// vararg and the spread operator *: spreading an array makes a copy.
package k09

fun sum(vararg xs: Int): Int { var s = 0; for (x in xs) s += x; return s }
fun identity(vararg xs: Int): IntArray = xs

fun sumArray(xs: IntArray): Int { var s = 0; for (x in xs) s += x; return s }   // Accept arrays directly on hot paths.

fun main() {
    val a = intArrayOf(1, 2, 3)
    check(identity(*a) !== a)            // The spread operator creates a copy.
    check(sum(*a) == sumArray(a))
    check(sum(1, 2, 3) == 6)             // Creates a new int[3] for each call.
    println("K09 ok")
}
```

### 7.9 Coroutines

Each `suspend` function compiles to a state machine and needs a continuation object when it actually suspends. Each `launch` or `async` also creates an object. Split CPU-heavy work into chunks; **do not launch one coroutine per element**.

`examples/kotlin/K10_Coroutines.kt`

```kotlin
// Each suspend function compiles to a state machine and needs a continuation when suspended; launch/async also allocate objects.
// Split small CPU-bound tasks into chunks instead of creating one coroutine per element.
package k10

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.runBlocking

suspend fun parallelSum(xs: IntArray, chunks: Int = Runtime.getRuntime().availableProcessors()): Long = coroutineScope {
    val size = (xs.size + chunks - 1) / chunks
    (0 until chunks).map { c ->
        async(Dispatchers.Default) {
            var s = 0L
            val end = minOf(xs.size, (c + 1) * size)
            for (i in c * size until end) s += xs[i]     // A regular loop with no suspension point or allocation inside the chunk.
            s
        }
    }.awaitAll().sum()
}

fun main() = runBlocking {
    val xs = IntArray(1_000_000) { 1 }
    check(parallelSum(xs) == 1_000_000L)
    println("K10 ok")
}
```

### 7.10 Primitive collections in androidx.collection

`androidx.collection` 1.4+ offers open-addressed primitive collections such as `IntList`, `MutableIntList`, `IntIntMap`, `IntObjectMap`, and `ScatterMap`. It works in non-Android JVM projects too; version 1.7.0 was measured locally.

`examples/kotlin/K12_AndroidxCollection.kt`

```kotlin
// Primitive collections in androidx.collection 1.4+ work with Kotlin Multiplatform and regular JVM projects.
package k12

import androidx.collection.MutableIntIntMap
import androidx.collection.MutableIntList
import androidx.collection.MutableIntObjectMap
import androidx.collection.SparseArrayCompat
import androidx.collection.mutableIntListOf

fun main() {
    val counts = MutableIntIntMap(64)                 // Open addressing; keys and values are ints.
    for (i in 0 until 1000) counts[i % 10] = counts.getOrDefault(i % 10, 0) + 1
    check(counts[3] == 100)

    val ids: MutableIntList = mutableIntListOf()
    for (i in 0 until 100) ids.add(i)
    var total = 0
    ids.forEach { total += it }                        // Inline; elements are passed as ints.
    check(total == 4950 && ids.size == 100)

    val names = MutableIntObjectMap<String>()
    names[42] = "answer"
    check(names[42] == "answer")

    val sparse = SparseArrayCompat<String>()            // Like android.util.SparseArray, uses sorted arrays and binary search.
    sparse.put(7, "seven")
    check(sparse[7] == "seven")
    println("K12 ok")
}
```

Sources: [Kotlin inline value classes](https://kotlinlang.org/docs/inline-classes.html) · [Inline functions](https://kotlinlang.org/docs/inline-functions.html) · [Kotlin 2.0 and `invokedynamic` lambdas](https://kotlinlang.org/docs/whatsnew20.html) · [Sequences](https://kotlinlang.org/docs/sequences.html) · [`lazy`](https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/lazy.html) · [Java interop: `@JvmField` and `const`](https://kotlinlang.org/docs/java-to-kotlin-interop.html) · [Coroutines basics](https://kotlinlang.org/docs/coroutines-basics.html) · [androidx.collection releases](https://developer.android.com/jetpack/androidx/releases/collection)

---

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

## 15. jvmperf-lint: find patterns automatically

`jvmperf-lint/` is the guide's static checker. It is written in Java and uses tree-sitter via the JVM bindings (`io.github.bonede:tree-sitter` with `tree-sitter-java` and `tree-sitter-kotlin`) to inspect `.java`, `.kt`, and `.kts` files. It reads syntax only and **does not resolve types**. This keeps it fast and configuration-free, but it can report false positives or miss issues; each rule documents its risk. See [`jvmperf-lint/README.md`](../../jvmperf-lint/README.md) for installation and usage.

```sh
cd jvmperf-lint
./gradlew jar
bin/jvmperf-lint path/to/src
bin/jvmperf-lint -f json --disable jp-finalize,jp-ui-text-append src
```

### 15.1 Rule catalog

Default severity is `error`, `hint`, or `off`, as printed by `bin/jvmperf-lint --list-rules`. Rules marked `off` do not run unless you select them with `--enable`.

| ID | Name | Default severity | Languages | Detection | Chapter |
|---|---|---|---|---|---|
| jp-boxed-primitive-collection | `boxed-primitive-collection` | off | Java/Kotlin | `List<Integer>`, `Map<Long,…>`, Kotlin `List<Int>`, `Array<Int>`, or `HashMap<Int,…>` | 3, 7.1 |
| jp-string-concat-hot | `string-concat-in-loop` | error | Java/Kotlin | `s += x` or `s = s + x` in a loop | 6.2 |
| jp-regex-hot | `regex-in-loop` | off | Java/Kotlin | `Pattern.compile`, `Regex(...)`, `replaceAll`, or non-fast-path `split` in a loop | 6.3 |
| jp-format-hot | `format-in-loop` | off | Java/Kotlin | `String.format`, `.formatted`, or Kotlin `.format` in a loop | 6.4 |
| jp-unpresized-collection | `unpresized-collection` | off | Java/Kotlin | A collection or `StringBuilder` is filled in a loop without initial capacity | 5.2 |
| jp-boxed-stream | `boxed-stream` | error | Java | `reduce(0, Integer::sum)` or `Collectors.summingInt` on `Stream<Integer>` | 3.1 |
| jp-exception-control-flow | `exception-control-flow` | off | Java/Kotlin | A loop catches parse exceptions to make a decision | 9.5 |
| jp-legacy-synchronized-type | — | **removed** | — | measured ~1.08×; see `evidence/_removed/` | — |
| jp-many-boolean-fields | — | **removed** | — | COH no win; see `evidence/_removed/` | — |
| jp-enum-key-hash-collection | `enum-key-hash-collection` | error | Java/Kotlin | `HashMap` keyed by an enum or `HashSet` of enum values | 5.3 |
| jp-collection-chain | `collection-chain` | off | Kotlin | A chain of 3+ `map`/`filter` operations, or 2 operations plus short-circuiting such as `first`, `take`, or `any` | 7.4 |
| jp-value-class-boxing | `value-class-boxing` | hint | Kotlin | A value class used as a nullable value, generic argument, or array element | 7.2 |
| jp-lambda-to-non-inline-hot | `lambda-to-non-inline-in-loop` | off | Kotlin | A loop passes a lambda to a non-inline higher-order function declared in the same file | 7.3 |
| jp-lazy-default-mode | `lazy-default-mode` | off | Kotlin | `by lazy { }` without an explicit mode | 7.5 |
| jp-data-copy-hot | `data-copy-in-loop` | error | Kotlin | `copy(...)` in a loop | 7.7 |
| jp-android-sparse-array | `android-sparse-array` | hint | Java/Kotlin | `HashMap<Integer/Long, …>` in Android source | 12.2 |
| jp-log-hot | `log-in-loop` | off | Java/Kotlin | `System.out.println`, `Log.d/v`, or an unguarded log call in a loop | 12.5 |
| jp-sleep-polling | `sleep-polling` | off | Java/Kotlin | A `while` loop that only sleeps and checks a condition | 10 |
| jp-finalize | `finalize` | hint | Java/Kotlin | Overrides `finalize()` | 9 |
| jp-expensive-alloc-hot | `expensive-alloc-in-loop` | off | Java/Kotlin | Constructs costly reusable objects such as `SimpleDateFormat`, `Random`, `ObjectMapper`, or `MessageDigest`, or a constant array of at least 256 bytes, inside a loop | 10.3 |
| jp-hot-heavy-alloc | `hot-heavy-alloc` | off | Java/Kotlin | Allocates `Paint`, `Path`, `Rect`, `Canvas`, `Matrix`, a bitmap, or an un-sized `ByteArrayOutputStream` in a hot context | 5.2, 12.5 |
| jp-hot-format-log | `hot-format-log` | off | Java/Kotlin | Formats strings or builds log messages in event callbacks; loop cases belong to jp-format-hot/jp-log-hot | 6.4, 12.5 |
| jp-hot-system-call | `hot-system-call` | hint | Java/Kotlin | Calls services, metrics, accessibility, package manager, settings, or Toast APIs in a hot context | 12.1 |
| jp-bitmap-decode-no-reuse | `bitmap-decode-no-reuse` | hint | Java/Kotlin | Calls `BitmapFactory.decode*` in a hot context without `inBitmap` reuse | 12.2, 10.3 |
| jp-hot-post-lambda | `hot-post-lambda` | hint | Java/Kotlin | Creates a new lambda for each event with `post { }` or `runOnUiThread { }` | 7.3 |
| jp-ui-text-append | `ui-text-append` | hint | Java/Kotlin | Assigns `new text + old text` to a `TextView`, copying and laying out the full string repeatedly | 6.2 |
| jp-baos-tobytearray-copy | `baos-tobytearray-copy` | error | Java/Kotlin | Copies the whole buffer with `ByteArrayOutputStream.toByteArray()` in a hot context | 8.3 |
| jp-hot-payload-copy | `hot-payload-copy` | error | Java/Kotlin | Allocates a payload-sized buffer and copies the whole payload in a hot context | 8.2, 8.3 |
| jp-client-factory-recreate | `client-factory-recreate` | error | Java/Kotlin | Recreates OkHttpClient / HttpClient-style factories instead of reusing | 10 |
| jp-string-intern-hot | `string-intern-in-loop` | error | Java/Kotlin | `String.intern()` inside a loop | 6 |
| jp-non-static-field-updater | `non-static-field-updater` | hint | Java | Non-static `Atomic*FieldUpdater` field | 9 |

The proposed rule `vt-unsafe-threadlocal-pool` is **guide-first** only (§10.2): high FP on ordinary `ThreadLocal` caches; not shipped (it is not in `Rule.RULES`). Paired samples live under `jvmperf-lint/fixtures/guide/` (not `bad/`/`good/`, so FixtureTest does not require a rule).

**Evidence-gated policy (keep / escalate):** package `evidence/<RULE>.{md,jsonl}` + [evidence-policy](../evidence-policy.md). Currently the default **error** rules are the eight that have both files: jp-string-concat-hot, jp-boxed-stream, jp-enum-key-hash-collection, jp-data-copy-hot, jp-baos-tobytearray-copy, jp-hot-payload-copy, jp-client-factory-recreate, jp-string-intern-hot. Rules with JSONL that stay below **error**: **hint** jp-value-class-boxing and jp-non-static-field-updater; **off** jp-boxed-primitive-collection, jp-regex-hot, jp-format-hot, jp-unpresized-collection, jp-exception-control-flow, jp-collection-chain, jp-lambda-to-non-inline-hot, jp-log-hot, and jp-expensive-alloc-hot. **Pending** (stub md only, mostly needing ART or a device): jp-lazy-default-mode, jp-android-sparse-array, jp-sleep-polling, jp-finalize, jp-hot-heavy-alloc, jp-hot-format-log, jp-hot-system-call, jp-bitmap-decode-no-reuse, jp-hot-post-lambda, jp-ui-text-append. See `scripts/run-static-vs-hotspot.sh`, [rule-regression](../../../../docs/rule-regression.md).

Suppress a finding with `// jvmperf-lint: ignore jp-boxed-primitive-collection,jp-string-concat-hot -- reason` on the current or previous line. Suppress rules for a file with `// jvmperf-lint: ignore-file jp-regex-hot`. Examples intentionally demonstrating a pattern use these directives.

**Hot-context inference (v0.3):** jp-hot-heavy-alloc–jp-hot-payload-copy infer why a source location may be hot instead of looking only for loops. Sources include non-periodic loops; event callbacks such as `onTouch`, `onDraw`, `onBindViewHolder`, `doFrame`, and `onImageAvailable`; lambdas registered as callbacks; names such as `onFrame` and `onJpeg`; user annotations (`// jvmperf-lint: hot`, `@HotPath`, or `--hot-fn`); and local call propagation (two levels in one file, one level across `Obj.f()` calls). Diagnostics show a reason chain such as `[hot: controlLoop:loop@404 → writeFrame → encode]`. Periodic loops, `accept()` loops, and catch blocks are excluded. jp-hot-format-log and jp-hot-post-lambda skip sampled branches such as `% NN`, `isLoggable`, `BuildConfig.DEBUG`, and `== ACTION_DOWN`.

The v0.3 hot-context rules were informed by Android screen-mirroring code reviews. They surfaced Binder calls and Toasts on every touch, per-frame `Bitmap`/`Canvas`/`ByteArrayOutputStream` allocations, text logs rebuilt by prepending new text, and full-frame copies.

### 15.2 Fixtures and tests

The `fixtures/bad/` and `fixtures/good/` directories contain Java and/or Kotlin fixtures for every **shipped** rule. Guide-only samples (`vt-unsafe-threadlocal-pool`) live under `fixtures/guide/`. They compile with javac 25 or kotlinc 2.4.21; Android fixtures compile against `android.jar`. Fixture and CLI tests run with `./gradlew test` (JUnit 5). They check rule coverage, clean fixtures, suppressions, JSON output, exit codes, hot-context call chains, and `--hot-fn`.

**Measured locally:** all 50 bad fixtures produced 76 findings in v0.3, and every file triggered its intended rule. The good fixtures produced no findings. A sample scan of 506 files in the JDK 25 `java.base/java/{util,text,io}` sources is recorded in `research/jdk-src-precision.txt`.

### 15.3 Comparison with other tools

`jvmperf-lint` complements established tools, especially for Kotlin allocation and boxing patterns and checks shared by Java and Kotlin. The following comparisons were checked against tool documentation on 2026-10-21.

| Tool | Approach | Relevant coverage | Requirements |
|---|---|---|---|
| [PMD](https://pmd.github.io/) 7.28.0 | Java source analysis | String concatenation, loop allocations, legacy synchronized collections, string-builder sizing, file streams, and array conversions | Source; auxiliary classpath for type resolution |
| [SpotBugs](https://spotbugs.github.io/) 4.10.5 | Bytecode analysis | String-buffer concatenation, regex compilation in loops, boxed primitives, map iteration, inner classes, and finalizers | Compiled `.class` files; Kotlin bytecode can produce more false positives |
| [find-sec-bugs](https://find-sec-bugs.github.io/bugs.htm) 1.14.0 | SpotBugs security plugin | Security checks; `REDOS` flags catastrophic regex backtracking | SpotBugs setup |
| [Error Prone](https://errorprone.info/bugpatterns) 2.50.0 | javac plugin | Obsolete JDK types, unnecessary boxing, wrapper constructors, finalizers, and string builders | Compile-time types; Java only |
| [detekt](https://detekt.dev/) 1.23.8 | Kotlin static analysis | Primitive arrays, sequence conversions, range loops, spread operators, and temporary objects | Some checks need type resolution and a classpath |
| [Android Lint](https://developer.android.com/studio/write/lint) | Android project analysis | Sparse collections, `valueOf`, draw allocations, logging, recycling, and ViewHolder patterns | Android project model, usually through AGP |
| [ktlint](https://github.com/pinterest/ktlint) 1.8.0 | Kotlin formatting and style | No performance rules | No compile required |
| [SonarQube / SonarLint](https://www.sonarsource.com/products/sonarlint/) | Multi-language analysis | Java string concatenation, legacy synchronized types, regex reuse, EnumMap/EnumSet; Kotlin focuses more on code smells and defects | Compiled output for full analysis |
| [Checkstyle](https://checkstyle.org/checks.html) 14.3.0 | Java style | No performance category; can forbid selected types or finalizers | No compile required |
| [IntelliJ inspections](https://www.jetbrains.com/help/inspectopedia/Java-Performance.html) | IDE analysis | About 40 Java performance checks plus Kotlin collection-chain conversions | IDE and type information |
| [OpenRewrite](https://docs.openrewrite.org/recipes) 2.45.0 | Automated refactoring | Rewrites string replacement, Stack usage, wrapper constructors, finalizers, and selected JDK migrations | Build plugin and type information |
| Runtime tools: [JOL](https://github.com/openjdk/jol), [JFR](https://docs.oracle.com/en/java/javase/25/jfapi/), [async-profiler](https://github.com/async-profiler/async-profiler), [JMH](https://github.com/openjdk/jmh) | Measurement | Measure object sizes, allocations, CPU hotspots, and time; use them to decide whether static findings matter | Run the application |

The main overlap is jp-string-concat-hot, the removed jp-legacy-synchronized-type, and jp-finalize/jp-expensive-alloc-hot with PMD; jp-regex-hot with SpotBugs and Sonar; jp-enum-key-hash-collection with Sonar and IntelliJ; and jp-collection-chain with detekt and IntelliJ. jvmperf-lint adds checks such as Kotlin `s +=` in loops, `value class` boxing, lambda allocation, `by lazy` defaults, coroutine/event-path allocations, and Android callbacks without requiring project compilation or type resolution.

Other tools detect useful patterns not covered here, including inefficient array conversions, incorrect map iteration, Kotlin spread operators, Android recycling and ViewHolder issues, and automated JDK migrations. A practical combination is Error Prone or PMD for Java, detekt for Kotlin, and Android Lint for Android projects. Treat every static warning as a hypothesis and use JFR, async-profiler, or JMH to confirm its impact.

### 15.4 Local comparison runs

PMD 7.28.0 was run on the bad Java fixtures with its full performance rules plus 10 related rules. It overlapped on jp-string-concat-hot, the since-removed jp-legacy-synchronized-type, jp-finalize, and jp-expensive-alloc-hot; its `AvoidInstantiatingObjectsInLoops` is broader and also reported harmless allocations in two good fixtures. Its performance rules did not include regex compilation inside loops. Full results are in `research/pmd-on-fixtures.txt` and the selected rule set is in `research/pmd-ruleset-compare.xml`.

detekt 1.23.8 was run on the bad Kotlin fixtures with `CouldBeSequence` enabled and style-noise rules disabled. It reported `ArrayPrimitive` twice for `Array<Long>`/`arrayOf(1L)` and `CouldBeSequence` once for a three-step chain; it did not report `List<Int>`, `HashMap<Int,Int>`, or the other 15 tested patterns. Its good fixtures had one unrelated `EmptyFunctionBlock` report. Probe files confirmed that `ForEachOnRange`, `SpreadOperator`, and `CouldBeSequence` work. `CouldBeSequence` required Kotlin stdlib 1.9.22 for type resolution; kotlinc 2.4.21's stdlib did not trigger it. Full results are in `research/detekt-on-fixtures.txt` and `research/detekt-probe-out.txt`.

Android Lint 8.2.0 was tested in standalone `--sources` mode. `LogConditional` (when enabled) and `UseValueOf` triggered, but `UseSparseArrays` did not report a `HashMap<Integer,String>`. Standalone mode may lack the AGP project model, so no conclusion is drawn about that rule. See `research/android-lint-probe.txt`.

SpotBugs, Error Prone, SonarQube, IntelliJ, and OpenRewrite were not run locally because they require compiled classes, compiler integration, a server, an IDE, or build plugins. Their mappings above come from their documentation. Check current versions before relying on the comparison.

### 15.5 Evidence gate and HotSpot correlation

Treat lint findings as review prompts until a rule has both `evidence/<RULE>.md` and `evidence/<RULE>.jsonl` (see [`docs/evidence-policy.md`](../evidence-policy.md)). Eight rules default to **error** (see the §15.1 note); several more have JSONL but stay **hint** or **off** when the correlate is modest, negative, or creation-only.

Cross-check: `scripts/run-static-vs-hotspot.sh` output under `research/benches/`. **Static lint ≠ HotSpot awareness** — do not claim C2 tier or failed escape analysis from source alone; do not use PrintCompilation line counts as the agree/disagree gate.

---

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

## References

**OpenJDK and Java**

- JDK 25, 26, and 27 project pages: <https://openjdk.org/projects/jdk/25/> · <https://openjdk.org/projects/jdk/26/> · <https://openjdk.org/projects/jdk/27/>
- JEP index, including Compact Strings (254), String Deduplication (192), Indify String Concatenation (280), `@Contended` (142), Epsilon (318), Virtual Threads (444), Compact Object Headers (450/519/534), FFM (454), ZGC (474/490), AOT (483/514/515/516), virtual-thread pinning (491), Scoped Values (506), Vector API (508/529/537), JFR CPU-time sampling (509), generational Shenandoah (521), and G1 changes (522/523): <https://openjdk.org/jeps/0>
- [HotSpot GC tuning guide](https://docs.oracle.com/en/java/javase/25/gctuning/)
- [Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/)
- Aleksey Shipilёv, [JVM Anatomy Quarks](https://shipilev.net/jvm/anatomy-quarks/)
- OpenJDK Wiki, [CompressedOops](https://wiki.openjdk.org/display/HotSpot/CompressedOops)

**Kotlin**

- Kotlin 2.0 and 2.4 release notes: <https://kotlinlang.org/docs/whatsnew20.html> · <https://kotlinlang.org/docs/whatsnew24.html>
- [Inline value classes](https://kotlinlang.org/docs/inline-classes.html) · [Inline functions](https://kotlinlang.org/docs/inline-functions.html) · [Sequences](https://kotlinlang.org/docs/sequences.html)

**Android**

- [ART runtime](https://source.android.com/docs/core/runtime) · [R8](https://developer.android.com/build/shrink-code) · [Baseline Profiles](https://developer.android.com/topic/performance/baselineprofiles/overview)
- [Android Lint checks](https://googlesamples.github.io/android-custom-lint-rules/checks/index.md.html)

**Libraries and tools**

- [fastutil](https://fastutil.di.unimi.it/) · [Eclipse Collections](https://eclipse.dev/collections/) · [androidx.collection](https://developer.android.com/jetpack/androidx/releases/collection)
- [JOL](https://github.com/openjdk/jol) · [JMH](https://github.com/openjdk/jmh) · [async-profiler](https://github.com/async-profiler/async-profiler) · [JFR API](https://docs.oracle.com/en/java/javase/25/jfapi/)
- [GraalVM Native Image](https://www.graalvm.org/jdk25/reference-manual/native-image/)
- Static analysis: [PMD](https://pmd.github.io/) · [SpotBugs](https://spotbugs.github.io/) · [find-sec-bugs](https://find-sec-bugs.github.io/) · [Error Prone](https://errorprone.info/) · [detekt](https://detekt.dev/) · [ktlint](https://github.com/pinterest/ktlint) · [Sonar](https://rules.sonarsource.com/java/) · [Checkstyle](https://checkstyle.org/) · [IntelliJ Inspectopedia](https://www.jetbrains.com/help/inspectopedia/) · [OpenRewrite](https://docs.openrewrite.org/)
- [tree-sitter](https://tree-sitter.github.io/tree-sitter/) · [tree-sitter-java](https://github.com/tree-sitter/tree-sitter-java) · [tree-sitter-kotlin](https://github.com/fwcd/tree-sitter-kotlin)
