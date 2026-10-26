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

