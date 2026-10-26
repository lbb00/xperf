## 2. 对象有多大：对象头、压缩指针、紧凑对象头

### 2.1 对象头

HotSpot 中每个对象都有对象头：

| 模式（64 位 JVM） | mark word | 类指针 | 数组长度 | 普通对象头合计 |
|---|---|---|---|---|
| 默认（JDK 25 及以前，压缩类指针） | 8 字节 | 4 字节 | 数组另加 4 字节 | **12 字节** |
| 紧凑对象头 `-XX:+UseCompactObjectHeaders`（JDK 24 实验 / 25 正式 / 27 默认） | 8 字节（类指针压进 mark word） | — | 数组另加 4 字节 | **8 字节** |

对象大小按 `ObjectAlignmentInBytes`（默认 8）对齐。所以：**最小对象**默认 16 字节，开启紧凑对象头后 `new Object()` 只有 8 字节。

**【本机实测】JOL 0.17，JDK 25.0.4.1：**

| 类型 | 默认 | `+UseCompactObjectHeaders` |
|---|---|---|
| `new Object()` | 16 | 8 |
| `Integer` / `Boolean` | 16 | 16 |
| `Long` | 24 | 16 |
| `class Point { int x, y; }` | 24 | 16 |
| `class { byte b; long l; int i; Object ref; boolean z; }` | 32 | 32 |
| `new int[0]` | 16 | 16 |
| `new int[1000]` / `new long[1000]` | 4016 / 8016 | 4016 / 8016 |
| 20 个 ASCII 字符的 `String`（含 `byte[]`） | 64 | 56 |

可以看到：紧凑对象头对"小对象"（`Long`、两个 `int` 的 `Point`）收益最大，对已经有填充空隙的对象（`Integer` 12+4=16）没有变化；数组本身的元素占用不变。JEP 534 给出的说法是"平均每个对象省 4 字节"。

```sh
# JDK 25：正式但默认关闭，可以直接打开
java -XX:+UseCompactObjectHeaders -jar app.jar
# JDK 27：默认开启，如需关闭
java -XX:-UseCompactObjectHeaders -jar app.jar
```

**不要用的时候**：依赖对象头布局的老旧本地代码/Agent（极少见）；JDK 25 上若你的 JVM 厂商构建有已知问题。打开前后用 JFR 或 GC 日志对比一下堆占用和停顿即可。

### 2.2 压缩指针（compressed oops）

64 位 JVM 默认把对象引用压缩成 32 位（`UseCompressedOops`，本机 `PrintFlagsFinal` 显示为 ergonomic 开启）。在 8 字节对齐下最多寻址约 32 GB 堆；**把 `-Xmx` 设到 32 GB 以上会让 JVM 关闭压缩指针**，所有引用变 8 字节，"更大的堆"反而能装下的对象更少。需要超大堆时要么直接跳到明显更大（如 48 GB+），要么考虑 `-XX:ObjectAlignmentInBytes=16`（扩大寻址范围、代价是每个对象的对齐浪费更多）。

### 2.3 字段布局

HotSpot 会重排字段：先按大小从大到小排，再用小字段填补头部和中间的空隙（见上面 `Mixed` 类的 JOL 输出：`int i` 被放在偏移 12 填补对象头后的空隙）。所以**Java 里声明字段的顺序不影响大小**——这和 C 的 struct 不同。能影响大小的只有：字段的类型和数量、对齐、继承（父类字段先排）。

```text
【本机实测】JolSizes$Mixed（默认对象头）
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

### 2.4 用 JOL 自己测

本章所有数字都来自这个程序（`research/JolSizes.java`，运行方法写在文件头注释里）：

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

**不要用的时候**：JOL 用于开发期测量，不要放进生产代码路径。JDK 25 上它会触发 `sun.misc.Unsafe` 与动态 agent 的警告，本机运行时加了 `-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading -Djol.magicFieldOffset=true --sun-misc-unsafe-memory-access=allow`。

来源：[JEP 450](https://openjdk.org/jeps/450) · [JEP 519](https://openjdk.org/jeps/519) · [JEP 534](https://openjdk.org/jeps/534) · [JOL](https://github.com/openjdk/jol) · [Aleksey Shipilёv: JVM Anatomy Quarks](https://shipilev.net/jvm/anatomy-quarks/) · [OpenJDK Wiki: CompressedOops](https://wiki.openjdk.org/display/HotSpot/CompressedOops)

---

## 3. 装箱与原始类型集合

### 3.1 装箱到底贵在哪里

`List<Integer>` 里每个元素都是一个独立的 `Integer` 对象：16 字节对象 + 4 字节引用，外加读取时的一次指针追逐（cache miss）和拆箱。`int[]` 每个元素 4 字节、连续存放。

**【本机实测】1000 个值（≥1000，避开 Integer 缓存）：**

| 容器 | 总字节（默认） | 总字节（紧凑对象头） | 对象个数 |
|---|---|---|---|
| `int[1000]` | 4,016 | 4,016 | 1 |
| `ArrayList<Integer>`（预设容量） | 20,040 | 20,040 | 1,002 |
| Kotlin `Array<Int>` | 20,016 | 20,016 | 1,001 |
| Kotlin `List<Int>` | 20,040 | 20,040 | 1,002 |
| `HashMap<Integer,Integer>` 1000 项 | 72,256 | 64,248 | 3,002 |
| fastutil `Int2IntOpenHashMap` 1000 项 | 16,496 | 16,480 | 3 |

也就是说装箱列表约为原始数组的 5 倍；`HashMap<Integer,Integer>` 约为 fastutil 原始类型 map 的 4.4 倍（默认对象头）。

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

要点：
- `Integer.valueOf` 只缓存 −128..127（`-XX:AutoBoxCacheMax` 可以调大上限，本机默认值 128）。**永远不要用 `==` 比较包装类型**。
- 流：用 `mapToInt(...).sum()`，不要 `map(...).reduce(0, Integer::sum)`（每一步都装箱）。
- C2 有 `EliminateAutoBox`（本机默认开启），能消除部分局部的装箱/拆箱，但对放进集合里的对象无能为力。

### 3.2 原始类型集合库

| 库 | 特点 | 状态 |
|---|---|---|
| [fastutil](https://fastutil.di.unimi.it/) | 覆盖面最全（`Int2IntOpenHashMap`、`IntArrayList`、大数组）；`fastutil-core` 是只含 int/long/double 的精简包（本机用的 8.5.19 约 6.6 MB） | 活跃 |
| [Eclipse Collections](https://eclipse.dev/collections/) | API 丰富（`IntLists.mutable`、`IntIntHashMap`、不可变集合），本机用 13.0.0 | 活跃 |
| [Koloboke](https://github.com/leventov/Koloboke) | 曾以性能著称 | 最后一次提交 2016 年，**不建议新项目使用** |
| [androidx.collection](https://developer.android.com/jetpack/androidx/releases/collection) | Kotlin 多平台；1.4+ 提供 `MutableIntList`、`MutableIntIntMap`、`IntObjectMap` 等；纯 JVM 也可用 | 活跃（本机 1.7.0） |

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

**不要用的时候**：集合很小（几十个元素）、或者 API 边界必须是 `List<Integer>`/`Map<K,V>` 时，引入一个大依赖不划算；Android 上额外依赖还会增加 APK 体积（R8 能裁掉未用到的类，但仍要评估）。

来源：[Integer.valueOf](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Integer.html#valueOf(int)) · [fastutil](https://fastutil.di.unimi.it/) · [Eclipse Collections](https://eclipse.dev/collections/) · [Koloboke 提交历史](https://github.com/leventov/Koloboke/commits/master/)

---

