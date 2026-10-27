# Java / Kotlin 极限性能指南：省内存与跑得快

> 目标版本：**JDK 25（当前 LTS，本机 Temurin 25.0.4.1）** + **Kotlin 2.4（本机 kotlinc 2.4.21）**，同时标注 JDK 21 / 26 / 27 的差异与 **Android（ART）** 的不同之处。
> 写作日期：2026-10-21。
>
> 约定：
> - 文中所有代码都来自 `examples/` 目录下的独立文件，**全部在本机编译并运行通过**（Java：`javac --release 25` + 运行自检；Kotlin：`kotlinc 2.4.21 -jvm-target 25` + 运行自检；Android：对 `android-34/android.jar` 编译）。编译日志见 `research/*-check.log`。本文提到的 `research/` 下的 `*.txt`、`*.log`、`bench-results/`、`benches/` 是本地运行输出，不入库。
> - 文中出现的字节数，凡标注 **【本机实测】** 的，都是用 JOL 0.17 在本机（x86_64 Linux，8 核，JDK 25.0.4.1，默认 G1、压缩指针开启）测得，原始输出见 `research/jol-jdk25.txt`、`research/jol-kotlin-jdk25.txt`、`research/ea-probe.txt`、`research/jvm-flags-jdk25.txt`。其他环境（不同 JDK、关闭压缩指针、ART）数字会不同。
> - 本文**不给出自己编造的加速比**。需要性能数字时请用第 14 章的 JMH 模板在你的机器上测。
> - 每节末尾给出来源链接；每个技巧都写了"什么时候不要用"。

## 目录

- [0. 版本须知](#0-版本须知)
- [1. 方法论：先估算、再测量](#1-方法论先估算再测量)
- [2. 对象有多大：对象头、压缩指针、紧凑对象头](#2-对象有多大对象头压缩指针紧凑对象头)
- [3. 装箱与原始类型集合](#3-装箱与原始类型集合)
- [4. 案例：一辆混动车在 JVM 上占多少内存](#4-案例一辆混动车在-jvm-上占多少内存)
- [5. 数据布局：原始数组、SoA、预设容量、EnumMap](#5-数据布局原始数组soa预设容量enummap)
- [6. 字符串](#6-字符串)
- [7. Kotlin 专项](#7-kotlin-专项)
- [8. 堆外内存与 I/O](#8-堆外内存与-io)
- [9. 让 JIT 帮你：逃逸分析、内联、intrinsic、Vector API](#9-让-jit-帮你逃逸分析内联intrinsicvector-api)
- [10. 并发：伪共享、虚拟线程、对象池](#10-并发伪共享虚拟线程对象池)
- [11. GC 选择与调优](#11-gc-选择与调优)
- [12. Android（ART）专项](#12-androidart专项)
- [13. GraalVM Native Image](#13-graalvm-native-image)
- [14. 度量工具：JMH、JFR、async-profiler、JOL](#14-度量工具jmhjfrasync-profilerjol)
- [15. jvmperf-lint：自动找出反模式](#15-jvmperf-lint自动找出反模式)（含 15.3 与 PMD / SpotBugs / Error Prone / detekt / Android Lint / Sonar / IntelliJ / OpenRewrite 等工具的对比）
- [16. 速查表](#16-速查表)
- [参考资料](#参考资料)

---

## 0. 版本须知

| 版本 | 与本文相关的变化 |
|---|---|
| JDK 21（上一个 LTS） | 虚拟线程正式（JEP 444）；分代 ZGC 引入（JEP 439，需 `-XX:+ZGenerational`） |
| JDK 22 | FFM API（`MemorySegment`/`Arena`）正式（JEP 454） |
| JDK 23 | 分代 ZGC 成为 ZGC 默认模式（JEP 474） |
| JDK 24 | 紧凑对象头实验版（JEP 450）；非分代 ZGC 移除（JEP 490）；`synchronized` 不再钉住虚拟线程（JEP 491）；AOT 类加载缓存（JEP 483） |
| **JDK 25（LTS）** | 紧凑对象头成为正式产品特性但**默认关闭**（JEP 519，`-XX:+UseCompactObjectHeaders`）；分代 Shenandoah 正式（JEP 521）；Vector API 第 10 轮孵化（JEP 508）；Stable Values 预览（JEP 502）；AOT 命令行简化与方法 profile（JEP 514/515）；JFR CPU 时间采样（实验，JEP 509） |
| JDK 26（2026-03） | G1 减少同步提升吞吐（JEP 522）；任意 GC 都可用 AOT 对象缓存（JEP 516）；Stable Values 改名 Lazy Constants（JEP 526，预览）；Vector API 第 11 轮孵化 |
| JDK 27（2026-09，非 LTS） | **紧凑对象头默认开启**（JEP 534）；G1 在所有环境下都是默认 GC（JEP 523）；Vector API 第 12 轮孵化（JEP 537，无 API 变化） |
| JDK 28（计划 2027-03） | Valhalla 的值类（JEP 401）以预览形式进入主线（据 InfoQ 报道），之后 Vector API 才会从孵化转为预览 |
| Kotlin 2.0 | K2 编译器；lambda 默认用 `invokedynamic` 生成（`-Xlambdas=indy`） |
| Kotlin 2.4（2026-06，当前 2.4.21） | 上下文参数等稳定；支持 Java 26 目标；不再能用 `-language-version 1.9` 回退到 K1 |
| Android | ART 不是 HotSpot：没有 C2、没有压缩指针开关（引用本来就是 32 位）、对象头 8 字节；默认 GC 为并发标记整理（CMC），Android 16 QPR2 起为分代 CMC。详见第 12 章 |

来源：[JDK 25](https://openjdk.org/projects/jdk/25/) · [JDK 26](https://openjdk.org/projects/jdk/26/) · [JDK 27](https://openjdk.org/projects/jdk/27/) · [JEP 534](https://openjdk.org/jeps/534) · [InfoQ: Java 27](https://www.infoq.com/news/2026/09/java27-released/) · [Kotlin 2.0 新特性](https://kotlinlang.org/docs/whatsnew20.html) · [Kotlin 2.4 新特性](https://kotlinlang.org/docs/whatsnew24.html) · [Kotlin 发布历史](https://kotlinlang.org/docs/releases.html)

---

## 1. 方法论：先估算、再测量

1. **先估算**：JVM 上"一个东西"的内存 ≈ 对象头 + 字段 + 对齐填充，再加上它引用的所有对象。第 2 章给出公式和本机实测值，写代码前就能算出 100 万个对象大约要多少内存。
2. **再测量**：
   - 对象大小 → JOL（`ClassLayout` / `GraphLayout`）；
   - 分配速率 → JMH `-prof gc` 的 `gc.alloc.rate.norm`（每次操作分配多少字节），或 `ThreadMXBean.getThreadAllocatedBytes`；
   - CPU 热点 → async-profiler / JFR；
   - 吞吐与延迟 → JMH（不要用 `System.nanoTime()` 包一个循环，JIT 预热、死代码消除、常量折叠都会让结果失真）。
3. **只优化热点**。对一个只会创建几十个实例的配置类做位压缩，是浪费时间；对一个装了 1000 万元素的 `List<Integer>` 改成 `int[]`，是数量级的收益（见第 3 章实测）。
4. **改完再测一次**，保留测试和断言。

工具用法见第 14 章。

---

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

## 4. 案例：一辆混动车在 JVM 上占多少内存

抖音上流行过一个 C/C++ 讲解：描述一辆车"有没有电动机、有没有汽油机"，用两个 `int` 要 8 字节，换成一个 `int` 位标志要 4 字节，再换成 `uint8_t` 只要 1 字节。把同样的思路搬到 JVM，结论会很不一样——因为**单个对象的大小由对象头和 8 字节对齐决定**。

### 4.1 单个对象：怎么压都是 16 字节

**【本机实测】JOL 0.17，JDK 25.0.4.1（`research/jol-jdk25.txt`、`research/jol-kotlin-jdk25.txt`）：**

| 写法 | C 里的大小 | JVM 默认 | `+UseCompactObjectHeaders` |
|---|---|---|---|
| `class { int electric; int benzine; }` | 8 | **24** | 16 |
| `class { int flags; }` | 4 | **16** | 16 |
| `class { byte flags; }` | 1 | **16** | 16 |
| `class { boolean electric, benzine, diesel; }` | 3 | **16** | 16 |
| `class { final EnumSet<Fuel> fuels; }`（持有者 + `RegularEnumSet`） | — | **48** | 40 |
| Kotlin `data class HybridBools(Boolean, Boolean, Boolean)` | — | 16 | 16 |
| Kotlin `data class HybridInts(Int, Int)` | — | 24 | 16 |
| Kotlin `class Car(val fuels: FuelFlags)`（`FuelFlags` 是包 `Byte` 的 value class） | — | 16 | 16 |

解读：
- 默认对象头 12 字节，后面放 4 字节以内的数据都还是 16 字节；`int`→`byte` 只是把填充变大了。
- 两个 `int` 的版本是 12+8=20，对齐到 24。打开紧凑对象头（8 字节头）后变成 16，**这个开关比你手工压缩字段更有效**。
- `EnumSet` 很方便，但它本身是一个对象（`RegularEnumSet` 内部是一个 `long`），作为字段会多出一个对象。

### 4.2 一千辆车：省内存的关键是"不要一车一个对象"

| 存储方式（1000 辆车） | JVM 默认 | 紧凑对象头 | 说明 |
|---|---|---|---|
| `HybridTwoInts[1000]` + 1000 个对象 | 28,016 | 20,016 | 【本机实测】 |
| `FlagsByte[1000]` + 1000 个对象 | 20,016 | 20,016 | 【本机实测】字段压到 1 字节也省不了多少 |
| Kotlin `Array<FuelFlags>`（value class 被装箱） | 20,016 | 20,016 | 【本机实测】 |
| `byte[1000]`（每车 1 字节） | 1,016 | 1,016 | 【本机实测】≈ C 的 `uint8_t[1000]` |
| `BitSet(3000)`（每车 3 位） | 416 | 416 | 【本机实测】`BitSet` 对象 + `long[]` |
| `long[47]`（`PackedFleet`，每车 3 位） | 392 | — | 计算值：16 字节数组头 + 47×8 |

所以在 JVM 上：
1. **单个对象里的标志位压缩几乎没有收益**（除非恰好跨过 8 字节对齐边界）。
2. **真正的收益来自把"对象数组"变成"原始类型数组"**（Structure of Arrays，见第 5 章）——从 20 KB 变成 1 KB，同时消除 1000 次指针追逐。
3. 标志位的编码方式（`byte` 位运算、`EnumSet`、`BitSet`）在数组层面才有意义；在对象层面优先考虑可读性。

Java 版本：

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

Kotlin 版本（`value class` 给 `Byte` 加上类型与运算符，运行时字段就是 `byte`）：

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

**什么时候不要这样做**：
- 车辆数量很小（几十、几百辆）时，`ByteArray`/位图会让代码变得难懂，而节省的内存可以忽略。
- 标志需要频繁并发修改时，同一个 `long`/`byte` 里的多个标志会互相竞争（需要 `AtomicLongArray` 或 `VarHandle` CAS），反而更复杂。
- 需要对外暴露为领域对象时：保留对象 API，在内部用原始数组存储（"flyweight"视图）。

来源：[JOL](https://github.com/openjdk/jol) · [EnumSet 文档](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/EnumSet.html) · [BitSet 文档](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/BitSet.html) · [Kotlin 位运算](https://kotlinlang.org/docs/numbers.html#bitwise-operations) · [Kotlin inline value classes](https://kotlinlang.org/docs/inline-classes.html)

---

## 5. 数据布局：原始数组、SoA、预设容量、EnumMap

### 5.1 AoS → SoA

对象数组（Array of Structures）在 JVM 上意味着：一个引用数组 + N 个分散在堆上的对象，每个都带对象头。把每个字段拆成一个原始数组（Structure of Arrays）后：没有对象头、没有指针追逐、只遍历一个字段时缓存命中率高，JIT 也更容易做循环向量化（C2 的 SuperWord）。

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

**不要用的时候**：对象需要作为整体传递、放进 `Map`、被多处引用；字段很多且总是一起访问；数据量小。SoA 也会让"删除一个元素"变成多个数组的同步操作。

### 5.2 集合预设容量

`ArrayList` 扩容按 1.5 倍复制底层数组；`HashMap` 按 2 倍扩容并重新散列。已知元素个数时：

- `new ArrayList<>(n)`；
- JDK 19+：`HashMap.newHashMap(n)` / `HashSet.newHashSet(n)` / `LinkedHashMap.newLinkedHashMap(n)`——参数是**元素个数**，内部已经按负载因子 0.75 换算；而 `new HashMap<>(n)` 的参数是**桶容量**，放进 n 个元素仍可能再扩容一次。
- Kotlin：`ArrayList<T>(n)`、`HashMap<K, V>(n)`（同样是桶容量）、`buildList(n) { }`、`IntArray(n)`。

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

### 5.3 枚举键：EnumMap / EnumSet

`EnumMap` 内部是按 `ordinal()` 索引的数组，`EnumSet`（≤64 个常量）内部是一个 `long` 位向量。**【本机实测】** 3 个枚举常量时，`EnumMap` 自身 + 值数组共 72 字节（紧凑对象头 64 字节），没有 `HashMap.Node`。

**不要用的时候**：需要 `null` 键（`EnumMap`/`EnumSet` 不允许）；键类型不止一种枚举。

### 5.4 Arrays 批量操作

`System.arraycopy`、`Arrays.fill`、`Arrays.equals`/`mismatch` 等都是 HotSpot intrinsic，比手写循环更快、更不容易写错。

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

来源：[HashMap.newHashMap（JDK 19，JDK-8186958）](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/HashMap.html#newHashMap(int)) · [EnumMap](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/EnumMap.html) · [Arrays](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Arrays.html)

---

## 6. 字符串

### 6.1 Compact Strings 与字符串去重

- JDK 9 起 `String` 内部是 `byte[]` + `coder`（JEP 254）：纯 Latin-1 内容每字符 1 字节，否则 UTF-16 每字符 2 字节。**【本机实测】** 20 个 ASCII 字符的 `String`（含 `byte[]`）64 字节，20 个汉字 80 字节。`-XX:-CompactStrings` 可关闭（本机默认开启），几乎没有理由关。
- `-XX:+UseStringDeduplication`：GC 在后台把**内容相同的 `String` 的底层数组**合并（`String` 对象本身仍各自存在）。最初只有 G1（JEP 192），JDK 18 起 Serial、Parallel、ZGC 也加入了支持（JDK-8272609 / 8267185 / 8267186）。本机默认关闭。适合"大量重复字符串长期存活"的服务（例如反序列化出来的大量相同字段值）。
- `String.intern()`：返回字符串常量池里的规范实例，之后可以用 `==` 比较、只保留一份对象。只适合**取值少、重复多、长期存活**的场景；对高基数的值调用 `intern()` 会把常量池（本质是一个 native 哈希表）撑大。很多时候用自己的 `HashMap<String,String>` 去重更可控。

### 6.2 拼接

- 单个表达式里的 `a + b + c` 没问题：javac 9+ 把它编译成 `invokedynamic` + `StringConcatFactory`（JEP 280）；Kotlin 的字符串模板在 JVM 9+ 目标下同样使用 indy 拼接。
- **循环里 `s += x` 是 O(n²)**：每次迭代都复制整个已有字符串。改用 `StringBuilder`（预估容量）、`String.join`、`StringJoiner`、`Collectors.joining`，Kotlin 用 `buildString(capacity) { }` / `joinToString`。
- `StringBuffer` 的每个方法都是 `synchronized`，单线程用 `StringBuilder`。

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

### 6.3 正则

`String.split(regex)`、`replaceAll`、`matches` 每次调用都会编译正则（`split` 对"单个非元字符"或"反斜杠 + 非字母数字"的参数有快路径）。热路径上把 `Pattern` 编译一次存成 `static final`；纯字面替换用 `String.replace(CharSequence, CharSequence)`。

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

**不要用的时候**：一次性脚本、启动时只跑一次的配置解析，没必要为了避免编译正则把代码拆散。

### 6.4 String.format

`String.format`/`formatted` 每次都要解析格式串，比 `StringBuilder` 拼接慢得多。热路径（日志除外，日志应该用参数化 API 并判断级别）用 `StringBuilder` 或预编译的 `java.text.MessageFormat`/`DateTimeFormatter`（后两者是线程安全的不可变对象时才可共享——`DateTimeFormatter` 是，`SimpleDateFormat` 不是）。

来源：[JEP 254 Compact Strings](https://openjdk.org/jeps/254) · [JEP 192 String Deduplication in G1](https://openjdk.org/jeps/192) · [JDK 18 发布说明（String Deduplication 扩展到其他 GC）](https://www.oracle.com/java/technologies/javase/18-relnote-issues.html) · [JEP 280 Indify String Concatenation](https://openjdk.org/jeps/280) · [String.split](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/String.html#split(java.lang.String)) · [Kotlin -Xstring-concat](https://kotlinlang.org/docs/compiler-reference.html#xstring-concat)

---

## 7. Kotlin 专项

Kotlin/JVM 最终也是 JVM 字节码，前面各章的结论都适用。本章讲 Kotlin 语法糖背后的分配与装箱。

### 7.1 `IntArray` vs `Array<Int>` vs `List<Int>`

| Kotlin 类型 | JVM 类型 | 1000 个值（≥1000）【本机实测】 |
|---|---|---|
| `IntArray` | `int[]` | 4,016 字节，1 个对象 |
| `Array<Int>` | `Integer[]` | 20,016 字节，1,001 个对象 |
| `List<Int>` | `ArrayList<Integer>` | 20,040 字节，1,002 个对象 |

`IntArray(n) { ... }`、`intArrayOf`、`for (x in intArray)`、`for (i in 0 until n)`、`xs.indices` 都编译成普通的 int 循环。`(0 until n).map { }` 会产生 `List<Int>`（装箱）；`(1..10).forEach { }` 会创建 `IntRange` 和迭代器，普通 `for` 不会。

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

**不要用的时候**：需要 `List` 的 API（不可变视图、与库交互）且数据量小——`List<Int>` 更符合习惯。

### 7.2 value class（`@JvmInline`）的装箱陷阱

`@JvmInline value class UserId(val raw: Int)` 在"以自身类型使用"时编译成 `int`。但下面几种用法会**装箱成真正的 `UserId` 对象**：

- 作为泛型参数：`List<UserId>`、`Map<UserId, …>`、`T`；
- 底层类型是原始类型时的可空：`UserId?`；
- 作为接口类型或 `Any` 使用。

示例里用反射检查了字段类型：`Holder(val id: UserId)` 的字段是 `int`，`NullableHolder(val id: UserId?)` 的字段是 `UserId`（装箱）。解决办法：用哨兵值代替 `null`；大批量数据用 `IntArray` 存原始值，需要时再包装。

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

**不要用的时候**：value class 主要提供类型安全；如果它总是被放进集合或可空字段，装箱后反而比直接用 `Int` 多一层对象，不如用普通 `Int` + 命名约定。

### 7.3 inline 函数、reified、lambda 分配

- `inline` 高阶函数：lambda 体被展开到调用点，**没有函数对象、没有装箱**（标准库的 `forEach`/`map`/`filter`/`sumOf`/`repeat` 都是 inline）。
- 非 inline 高阶函数：lambda 是一个对象，泛型的 `(Int) -> Int` 走 `Function1.invoke(Object)`，参数和返回值都装箱。热路径上要么 `inline`，要么用 `fun interface IntOp { fun apply(x: Int): Int }` 这样的原始类型签名。
- Kotlin 2.0 起 lambda 默认用 `invokedynamic`（`LambdaMetafactory`）生成：**不捕获变量的 lambda 在同一调用点复用同一个实例，捕获变量的每次求值都新建对象**（示例里用 `===` 验证了这一点）。
- `reified`：inline 函数里直接拿到类型参数，免去传 `Class` 对象和反射。

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

**不要用的时候**：大函数加 `inline` 会让每个调用点都复制一份字节码（代码膨胀，反而可能超过 JIT 的内联预算）；`inline` 适合小的高阶函数。

### 7.4 Sequence vs 集合操作

集合的每个 `map`/`filter` 都会生成一个完整的中间 `List`。`asSequence()` 改为逐元素流水线、支持提前终止。**适用**：多步链式 + 大数据量或 `first`/`take` 提前终止。**不适用**：小集合（序列每步有额外对象和虚调用，往往更慢）；只有一步操作；需要随机访问。注意 `Sequence<Int>` 的元素同样是装箱的，纯数值计算直接写循环。

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

### 7.5 `by lazy`

默认模式 `SYNCHRONIZED`：每个属性多一个 `Lazy` 对象 + lambda，首次访问加锁。单线程（例如 Android 主线程）用 `lazy(LazyThreadSafetyMode.NONE)`；初始化幂等可用 `PUBLICATION`。实例数量巨大的类上不要用 `by lazy` 字段（每个实例都多两个对象），改用手写缓存字段。

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

### 7.6 `const val`、`@JvmField`、companion object

- `const val`：编译期常量，直接内联到使用处。
- `companion object` 里的普通 `val`：私有静态字段 + `Companion.getXxx()`；JIT 一般能内联掉，但 Java 调用方和启动阶段（解释执行）仍要走 getter。`@JvmField` 生成公开字段、去掉 getter。
- 这些主要影响 API 形态和冷启动（Android 上更明显），对稳态性能影响很小——不要为此牺牲封装。

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

### 7.7 data class `copy()`

`copy()` 每次分配一个新对象。热循环里逐步 `copy` 会产生大量短命对象（逃逸分析不一定能消除，尤其是对象跨越循环迭代存活时）。热路径用局部变量累积，最后构造一次。

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

**不要用的时候**：不可变数据带来的正确性通常比几次分配更重要；只在 profiler 指出分配热点时再改。

### 7.8 vararg 与展开运算符 `*`

`f(*array)` 会**复制**数组（示例用 `!==` 验证）；`f(1, 2, 3)` 每次调用新建数组。热路径上提供直接接收 `IntArray` 的重载。

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

### 7.9 协程

每个 `suspend` 函数编译成状态机，真正挂起时需要续体（continuation）对象；每个 `launch`/`async` 也是对象。CPU 密集任务要分块，**不要每个元素开一个协程**。

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

### 7.10 androidx.collection（Kotlin 多平台原始类型集合）

`androidx.collection` 1.4+ 提供 `IntList`/`MutableIntList`、`IntIntMap`、`IntObjectMap`、`ScatterMap` 等原始类型、开放寻址容器，纯 JVM 项目也能用（本机 1.7.0）。

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

来源：[Kotlin inline value classes](https://kotlinlang.org/docs/inline-classes.html) · [Inline functions](https://kotlinlang.org/docs/inline-functions.html) · [Kotlin 2.0：invokedynamic 生成 lambda](https://kotlinlang.org/docs/whatsnew20.html) · [Sequences](https://kotlinlang.org/docs/sequences.html) · [lazy](https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/lazy.html) · [Java 互操作：@JvmField / const](https://kotlinlang.org/docs/java-to-kotlin-interop.html) · [Coroutines 基础](https://kotlinlang.org/docs/coroutines-basics.html) · [androidx.collection 版本说明](https://developer.android.com/jetpack/androidx/releases/collection)

---

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

## 15. jvmperf-lint：自动找出反模式

`jvmperf-lint/` 是本指南配套的静态检查器：Java + tree-sitter（JVM 绑定 `io.github.bonede:tree-sitter`，以及 `tree-sitter-java` / `tree-sitter-kotlin`），同时支持 `.java`、`.kt`、`.kts`。它只看语法树，**不做类型解析**，所以快、零配置、不需要编译项目，但会有误报/漏报（每条规则都写明了误报风险）。完整说明见 [`jvmperf-lint/README.md`](../../jvmperf-lint/README.md)。

```sh
cd jvmperf-lint
./gradlew jar
bin/jvmperf-lint path/to/src          # 文本输出；有发现时退出码 1
bin/jvmperf-lint -f json --disable jp-finalize,jp-ui-text-append src
```

### 15.1 规则一览

默认级别为 `error`、`hint` 或 `off`，与 `bin/jvmperf-lint --list-rules` 的输出一致。标为 `off` 的规则默认不运行，需用 `--enable` 选中。

| 编号 | 名字 | 默认级别 | 语言 | 检查什么 | 对应章节 |
|---|---|---|---|---|---|
| jp-boxed-primitive-collection | boxed-primitive-collection | off | J/K | `List<Integer>`、`Map<Long,…>`、Kotlin `List<Int>`/`Array<Int>`/`HashMap<Int,…>` | 3、7.1 |
| jp-string-concat-hot | string-concat-in-loop | error | J/K | 循环内 `s += x` / `s = s + x` | 6.2 |
| jp-regex-hot | regex-in-loop | off | J/K | 循环内 `Pattern.compile`、`Regex(…)`、`replaceAll`、非快路径 `split` | 6.3 |
| jp-format-hot | format-in-loop | off | J/K | 循环内 `String.format` / `.formatted` / Kotlin `.format` | 6.4 |
| jp-unpresized-collection | unpresized-collection | off | J/K | 无初始容量的集合 / `StringBuilder` 在循环中填充 | 5.2 |
| jp-boxed-stream | boxed-stream | error | J | `Stream<Integer>` 上 `reduce(0, Integer::sum)`、`Collectors.summingInt` | 3.1 |
| jp-exception-control-flow | exception-control-flow | off | J/K | 循环里 try/catch 解析异常做判断 | 9.5 |
| jp-legacy-synchronized-type | — | **removed** | — | measured ~1.08×; see `evidence/_removed/` | — |
| jp-many-boolean-fields | — | **removed** | — | COH no win; see `evidence/_removed/` | — |
| jp-enum-key-hash-collection | enum-key-hash-collection | error | J/K | 枚举键 `HashMap` / 枚举元素 `HashSet` | 5.3 |
| jp-collection-chain | collection-chain | off | K | ≥ 3 步 `map/filter/…` 链，或 2 步 + 短路终止（`first`/`take`/`any`…） | 7.4 |
| jp-value-class-boxing | value-class-boxing | hint | K | value class 用作可空 / 泛型 / 数组元素 | 7.2 |
| jp-lambda-to-non-inline-hot | lambda-to-non-inline-in-loop | off | K | 循环里把 lambda 传给本文件中的非 inline 高阶函数 | 7.3 |
| jp-lazy-default-mode | lazy-default-mode | off | K | `by lazy { }` 未指定模式 | 7.5 |
| jp-data-copy-hot | data-copy-in-loop | error | K | 循环里 `copy(…)` | 7.7 |
| jp-android-sparse-array | android-sparse-array | hint | J/K | Android 文件中 `HashMap<Integer/Long, …>` | 12.2 |
| jp-log-hot | log-in-loop | off | J/K | 循环内 `System.out.println`、`Log.d/v`、未判断级别的日志 | 12.5 |
| jp-sleep-polling | sleep-polling | off | J/K | `while` 里只有 `Thread.sleep` + 条件检查的纯轮询 | 10 |
| jp-finalize | finalize | hint | J/K | 重写 `finalize()` | 9 |
| jp-expensive-alloc-hot | expensive-alloc-in-loop | off | J/K | 循环内 `new SimpleDateFormat/Random/ObjectMapper/MessageDigest/…`、常量大小 ≥ 256 的数组 | 10.3 |
| jp-hot-heavy-alloc | hot-heavy-alloc | off | J/K | 热上下文里 `Paint()`/`Path()`/`Rect()`/`Canvas()`/`Matrix()`、`Bitmap.createBitmap`、无容量的 `ByteArrayOutputStream()` | 5.2、12.5 |
| jp-hot-format-log | hot-format-log | off | J/K | 逐事件回调里的 `String.format` / `"%.2f".format` / 拼接的 `Log` 消息（循环内的归 jp-format-hot/jp-log-hot） | 6.4、12.5 |
| jp-hot-system-call | hot-system-call | hint | J/K | 热上下文里 `getSystemService`、`getRealMetrics`、`getEnabledAccessibilityServiceList`、PackageManager 查询、`Settings.*.get*`、`Toast.makeText` | 12.1 |
| jp-bitmap-decode-no-reuse | bitmap-decode-no-reuse | hint | J/K | 热上下文里 `BitmapFactory.decode*` 没有 `inBitmap` 复用 | 12.2、10.3 |
| jp-hot-post-lambda | hot-post-lambda | hint | J/K | 每个事件 `post { }` / `runOnUiThread { }` 一个新 lambda | 7.3 |
| jp-ui-text-append | ui-text-append | hint | J/K | `tv.text = 新行 + tv.text`（每次复制并重排全文，不要求热上下文） | 6.2 |
| jp-baos-tobytearray-copy | baos-tobytearray-copy | error | J/K | 热上下文里 `ByteArrayOutputStream.toByteArray()` 的额外整块复制 | 8.3 |
| jp-hot-payload-copy | hot-payload-copy | error | J/K | 热上下文里按 `payload.size` 新建缓冲再整体 `put(payload)`/`copyInto`/`arraycopy` | 8.2、8.3 |
| jp-client-factory-recreate | client-factory-recreate | error | J/K | 在短生命周期或循环内重复新建 OkHttpClient / Retrofit 这类工厂对象，而不是复用 | 10 |
| jp-string-intern-hot | string-intern-in-loop | error | J/K | 循环内调用 `String.intern()` | 6 |
| jp-non-static-field-updater | non-static-field-updater | hint | Java | 非 `static` 的 `Atomic*FieldUpdater` 字段 | 9 |

忽略：`// jvmperf-lint: ignore jp-boxed-primitive-collection,jp-string-concat-hot -- 原因`（作用于本行和下一行），`// jvmperf-lint: ignore-file jp-regex-hot`。本指南 `examples/` 中故意保留的反例都用这种注释标注了。

**热上下文（v0.3）**：jp-hot-heavy-alloc–jp-hot-payload-copy 不只看语法循环，而是给每个位置推断一个“热原因”，写在消息末尾 `[热: …]`：非周期循环；逐事件回调（`onTouch`、`onDraw`、`onBindViewHolder`、`doFrame`、`onImageAvailable` 等，`--hot-callbacks` 可追加）；注册给回调的 lambda（`setOnTouchListener { }`、`setOnImageAvailableListener`、`postFrameCallback`、`collect { }`）；名字像逐帧/逐包的参数或属性（`onFrame = { }`、`onJpeg = { }`）；用户标注（`// jvmperf-lint: hot`、`@HotPath`、`--hot-fn 正则`）；再沿调用传播（本文件两层，跨文件 `Obj.f()` 一层），例如 `[热: controlLoop:循环@404 → writeFrame → encode]`。周期循环（`sleep(≥500)` 或 interval/backoff 类变量）、`accept()` 循环和 `catch` 块不算热；jp-hot-format-log/jp-hot-post-lambda 跳过采样分支（`% NN`、`isLoggable`、`BuildConfig.DEBUG`、`== ACTION_DOWN`）。这些规则参考了 Android 投屏代码评审中发现的逐触摸 Binder 调用和 Toast、逐帧 `Bitmap`/`Canvas`/`ByteArrayOutputStream` 分配、日志区 `text = 新 + 旧`、逐帧整帧复制等问题。

### 15.2 夹具与测试

`fixtures/bad/` 与 `fixtures/good/` 下每条规则都有 Java 和/或 Kotlin 夹具（各 51 个文件，能被 javac 25 / kotlinc 2.4.21 编译，Android 夹具对 `android.jar` 编译）。`./gradlew test` 验证：每个 bad 夹具触发其规则（并且用 `--enable` 单独启用时也触发）、good 夹具 0 发现、忽略注释、JSON 格式、退出码、启动脚本，以及热上下文的跨文件原因链（`fixtures/hot_xfile/`）和 `--hot-fn`。

**【本机实测】输出示例**（v0.3 的输出；jp-regex-hot 现在默认为 `off`，需加 `--enable jp-regex-hot` 才会报告）：

```text
$ bin/jvmperf-lint fixtures/bad/jp-regex-hot.java fixtures/bad/jp-value-class-boxing.kt
fixtures/bad/jp-regex-hot.java:6:17: warning[jp-regex-hot regex-in-loop] 循环内编译正则表达式 / regular expression compiled inside a loop: Pattern.compile(...)
    建议: 把 Pattern.compile / Regex(...) 提为 static final / companion 常量；String.replaceAll/replaceFirst/matches 每次都会编译正则，字面替换用 replace(CharSequence)
fixtures/bad/jp-regex-hot.java:7:18: warning[jp-regex-hot regex-in-loop] ...: .split("\\s+")：非单字符快路径，每次编译正则
fixtures/bad/jp-regex-hot.java:8:13: warning[jp-regex-hot regex-in-loop] ...: .replaceAll(...)：每次调用都编译正则
fixtures/bad/jp-value-class-boxing.kt:4:26: info[jp-value-class-boxing value-class-boxing] ...: UserId?：可空的 value class 被装箱
fixtures/bad/jp-value-class-boxing.kt:5:14: info[jp-value-class-boxing value-class-boxing] ...: List<UserId>：泛型参数中的 UserId 被装箱
fixtures/bad/jp-value-class-boxing.kt:5:29: info[jp-value-class-boxing value-class-boxing] ...: Array<UserId>：数组元素被装箱
```

全部 bad 夹具：50 个文件 76 处发现（v0.3），每个文件都触发了自己的规则；good 夹具：0 处。在 JDK 25 自带源码 `java.base/java/{util,text,io}`（506 个文件）上的抽查结果见 `research/jdk-src-precision.txt`。

### 15.3 与现有开源工具的对比

jvmperf-lint 不是要替代成熟工具，而是补上"Kotlin 专属的分配/装箱问题"和"跨 Java/Kotlin 统一的循环内反模式"这两块。下表把我们的规则映射到其他工具中**已核对过文档**的等价规则（链接均已于 2026-10-21 访问验证）。

#### 各工具概览

| 工具 | 类型 | 覆盖什么（与性能相关的部分） | 是否需要编译/类型信息 |
|---|---|---|---|
| [PMD](https://pmd.github.io/)（7.28.0）[performance 规则集](https://docs.pmd-code.org/latest/pmd_rules_java_performance.html) | Java 源码静态分析 | `UseStringBufferForStringAppends`、`AvoidInstantiatingObjectsInLoops`、`UseArrayListInsteadOfVector`、`InsufficientStringBufferDeclaration`、`AvoidFileStream`、`OptimizableToArrayCall`、`AddEmptyString`、`InefficientEmptyStringCheck` 等约 20 条；另有 bestpractices 中的 `ReplaceVectorWithList`、`ReplaceHashtableWithMap`、`AvoidStringBufferField`，errorprone 中的 finalize 系列 | 源码；类型解析需 auxclasspath |
| [SpotBugs](https://spotbugs.github.io/)（4.10.5）[PERFORMANCE 类别](https://spotbugs.readthedocs.io/en/latest/bugDescriptions.html) | 字节码分析 | `SBSC_USE_STRINGBUFFER_CONCATENATION`、`IIL_PATTERN_COMPILE_IN_LOOP(_INDIRECT)`、`DM_BOXED_PRIMITIVE_*`、`BX_*` 装箱拆箱、`WMI_WRONG_MAP_ITERATOR`、`SIC_INNER_SHOULD_BE_STATIC`、`DM_STRING_CTOR`、`DMI_RANDOM_USED_ONLY_ONCE`（在 BAD_PRACTICE 中）、`FI_*` finalize 系列 | 需要编译后的 .class；Kotlin 字节码也能分析，但误报多 |
| [find-sec-bugs](https://find-sec-bugs.github.io/bugs.htm)（1.14.0） | SpotBugs 安全插件 | 安全规则；与性能唯一沾边的是 `REDOS`（灾难性回溯正则） | 同 SpotBugs |
| [Error Prone](https://errorprone.info/bugpatterns)（2.50.0） | javac 插件 | [`JdkObsolete`](https://errorprone.info/bugpattern/JdkObsolete)（LinkedList/Vector/Hashtable/Stack/StringBuffer）、[`UnnecessaryBoxedVariable`](https://errorprone.info/bugpattern/UnnecessaryBoxedVariable)、[`UnnecessaryBoxedAssignment`](https://errorprone.info/bugpattern/UnnecessaryBoxedAssignment)、[`BoxedPrimitiveConstructor`](https://errorprone.info/bugpattern/BoxedPrimitiveConstructor)、[`Finalize`](https://errorprone.info/bugpattern/Finalize)、[`UnnecessaryStringBuilder`](https://errorprone.info/bugpattern/UnnecessaryStringBuilder) | 编译期，有完整类型；仅 Java |
| [detekt](https://detekt.dev/)（稳定版 1.23.8；2.0 在 alpha）[performance 规则集](https://detekt.dev/docs/rules/performance/) | Kotlin 静态分析 | `ArrayPrimitive`、`CouldBeSequence`（默认关闭）、`ForEachOnRange`、`SpreadOperator`、`UnnecessaryTemporaryInstantiation`、`UnnecessaryTypeCasting`、（2.0）`UnnecessaryInitOnArray`、`UnnecessaryPartOfBinaryExpression` | 部分规则需类型解析（`--classpath`） |
| [Android Lint](https://developer.android.com/studio/write/lint)（[检查列表](https://googlesamples.github.io/android-custom-lint-rules/checks/index.md.html)） | Android 项目分析 | [`UseSparseArrays`](https://googlesamples.github.io/android-custom-lint-rules/checks/UseSparseArrays.md.html)、[`UseValueOf`](https://googlesamples.github.io/android-custom-lint-rules/checks/UseValueOf.md.html)、[`DrawAllocation`](https://googlesamples.github.io/android-custom-lint-rules/checks/DrawAllocation.md.html)、[`LogConditional`](https://googlesamples.github.io/android-custom-lint-rules/checks/LogConditional.md.html)（默认关闭）、[`Recycle`](https://googlesamples.github.io/android-custom-lint-rules/checks/Recycle.md.html)、[`ViewHolder`](https://googlesamples.github.io/android-custom-lint-rules/checks/ViewHolder.md.html) 等 Performance 类别 | 需要 Android 项目模型（通常经 AGP） |
| [ktlint](https://github.com/pinterest/ktlint)（1.8.0，[规则](https://ktlint.github.io/ktlint/latest/rules/standard/)） | Kotlin 格式化/风格 | **只管代码风格**，没有性能规则 | 否 |
| [SonarQube / SonarLint（SonarQube for IDE）](https://www.sonarsource.com/products/sonarlint/)，[sonar-java](https://github.com/SonarSource/sonar-java) 8.44 | 多语言平台 | Java：[S1643](https://rules.sonarsource.com/java/rspec-1643/) 循环内字符串拼接、[S1149](https://rules.sonarsource.com/java/rspec-1149/) 同步遗留类、[S4248](https://rules.sonarsource.com/java/rspec-4248/) 正则不必要地重复编译、[S1640](https://rules.sonarsource.com/java/rspec-1640/) 枚举键用 EnumMap、[S1641](https://rules.sonarsource.com/java/rspec-1641/) 枚举集合用 EnumSet 等；Kotlin 规则以代码异味/缺陷为主 | 需要编译产物做完整分析 |
| [Checkstyle](https://checkstyle.org/checks.html)（14.3.0） | Java 风格 | 没有性能类别；[`NoFinalizer`](https://checkstyle.org/checks/coding/nofinalizer.html)，以及可配置的 [`IllegalInstantiation`](https://checkstyle.org/checks/coding/illegalinstantiation.html) / [`IllegalType`](https://checkstyle.org/checks/coding/illegaltype.html)（可用来禁用 `Vector`、`Hashtable`、`HashMap` 等） | 否 |
| IntelliJ IDEA 检查（[Java › Performance](https://www.jetbrains.com/help/inspectopedia/Java-Performance.html)） | IDE | 约 40 条：[字符串循环拼接](https://www.jetbrains.com/help/inspectopedia/StringContatenationInLoop.html)、[循环内分配对象](https://www.jetbrains.com/help/inspectopedia/ObjectAllocationInLoop.html)、[集合无初始容量](https://www.jetbrains.com/help/inspectopedia/CollectionWithoutInitialCapacity.html)、[动态正则可换成预编译 Pattern](https://www.jetbrains.com/help/inspectopedia/DynamicRegexReplaceableByCompiledPattern.html)、[EnumMap](https://www.jetbrains.com/help/inspectopedia/MapReplaceableByEnumMap.html)/[EnumSet](https://www.jetbrains.com/help/inspectopedia/SetReplaceableByEnumSet.html)、[自动装箱](https://www.jetbrains.com/help/inspectopedia/boxing.html)、[Busy wait](https://www.jetbrains.com/help/inspectopedia/BusyWait.html)；Kotlin：[集合调用链可转为 Sequence](https://www.jetbrains.com/help/inspectopedia/ConvertCallChainIntoSequence.html) | IDE 内有完整类型；可用 `inspect.sh` 无界面运行，但依赖 IDE 安装 |
| [OpenRewrite](https://docs.openrewrite.org/recipes)（rewrite-static-analysis 2.45.0） | 自动重构配方 | 不报告而是**改代码**：[`UseStringReplace`](https://docs.openrewrite.org/recipes/staticanalysis/usestringreplace)、[`ReplaceStackWithDeque`](https://docs.openrewrite.org/recipes/staticanalysis/replacestackwithdeque)、[`PrimitiveWrapperClassConstructorToValueOf`](https://docs.openrewrite.org/recipes/staticanalysis/primitivewrapperclassconstructortovalueof)、[`NoFinalizer`](https://docs.openrewrite.org/recipes/staticanalysis/nofinalizer)、[`RemoveCallsToObjectFinalize`](https://docs.openrewrite.org/recipes/staticanalysis/removecallstoobjectfinalize)、[`RemoveCallsToSystemGc`](https://docs.openrewrite.org/recipes/staticanalysis/removecallstosystemgc)；以及版本迁移配方（如 [UpgradeToJava25](https://docs.openrewrite.org/recipes/java/migrate/upgradetojava25)） | 需要构建插件 + 类型信息 |
| 运行时工具：[JOL](https://github.com/openjdk/jol)、[JFR](https://docs.oracle.com/en/java/javase/25/jfapi/)、[async-profiler](https://github.com/async-profiler/async-profiler)、[JMH](https://github.com/openjdk/jmh) | 测量 | 不找"写法问题"，而是告诉你**真实的**对象大小、分配热点、CPU 热点和耗时。静态工具（包括本工具）的每条提示都应由它们确认是否值得修 | 运行程序 |

#### 规则映射（我们的规则 → 已有的等价规则）

| jvmperf-lint | PMD | SpotBugs | Error Prone | detekt | Android Lint | Sonar（Java） | IntelliJ | OpenRewrite | 仍由本工具补充的部分 |
|---|---|---|---|---|---|---|---|---|---|
| jp-boxed-primitive-collection 装箱集合 | — | 仅 `BX_*`（局部装箱拆箱） | `UnnecessaryBoxedVariable`（局部变量） | `ArrayPrimitive`（仅 `Array<Int>` 等） | — | — | `boxing`（逐表达式） | — | Java 泛型集合 + Kotlin `List<Int>`/`HashMap<Int,…>` 字段/变量类型层面的提示 |
| jp-string-concat-hot 循环拼接 | `UseStringBufferForStringAppends` | `SBSC_USE_STRINGBUFFER_CONCATENATION` | — | — | — | S1643 | `StringContatenationInLoop` | — | **Kotlin** 的 `s += "$x"` |
| jp-regex-hot 循环内正则 | — | `IIL_PATTERN_COMPILE_IN_LOOP(_INDIRECT)` | （`StringSplitter` 管语义不管性能） | — | — | S4248（不限循环） | `DynamicRegexReplaceableByCompiledPattern` | `UseStringReplace` | Kotlin `Regex(...)`/`toRegex()` 在循环内；`split` 快路径判断 |
| jp-format-hot 循环内 format | — | — | — | — | — | — | — | — | 全部 |
| jp-unpresized-collection 未预设容量 | `InsufficientStringBufferDeclaration`（仅 StringBuilder） | — | — | — | — | — | `CollectionWithoutInitialCapacity`、`StringBufferWithoutInitialCapacity` | — | 仅在"循环中填充"时报告，Kotlin 同样适用 |
| jp-boxed-stream 装箱 Stream 归约 | — | — | — | — | — | — | — | — | 全部（启发式） |
| jp-exception-control-flow 异常做控制流 | `ExceptionAsFlowControl`（仅本方法内 throw 后 catch） | — | — | — | — | — | `ThrowCaughtLocally`（同上） | — | 循环里"try 解析 + catch 判断"模式，Java/Kotlin |
| jp-legacy-synchronized-type 遗留同步类型（规则已移除） | `ReplaceVectorWithList`、`ReplaceHashtableWithMap`、`UseArrayListInsteadOfVector`、`AvoidStringBufferField` | — | `JdkObsolete` | — | — | S1149 | `UseOfObsoleteCollectionType` | `ReplaceStackWithDeque`（仅 Stack） | Kotlin 中的 `Vector()`/`StringBuffer()` |
| jp-many-boolean-fields 多个 boolean 字段（规则已移除） | — | — | — | — | — | — | — | — | 全部 |
| jp-enum-key-hash-collection 枚举键哈希集合 | — | — | — | — | — | S1640、S1641 | `MapReplaceableByEnumMap`、`SetReplaceableByEnumSet` | — | Kotlin `HashMap<Color,…>()`/`mutableMapOf<Color,…>()` |
| jp-collection-chain 集合链 | — | — | — | `CouldBeSequence`（默认关闭，需类型解析） | — | — | `ConvertCallChainIntoSequence` | — | 无需类型解析、命令行可用 |
| jp-value-class-boxing value class 装箱 | — | — | — | — | — | — | — | — | 全部 |
| jp-lambda-to-non-inline-hot 非 inline 高阶函数 + lambda | — | — | — | — | — | — | — | — | 全部（限同文件声明） |
| jp-lazy-default-mode `by lazy` 默认模式 | — | — | — | — | — | — | — | — | 全部 |
| jp-data-copy-hot 循环内 `copy()` | — | — | — | — | — | — | — | — | 全部 |
| jp-android-sparse-array SparseArray | — | — | — | — | `UseSparseArrays` | — | （Android 插件同一检查） | — | 不需要 Android 项目模型 |
| jp-log-hot 循环内日志 | `SystemPrintln`（bestpractices，不限循环） | — | — | — | `LogConditional`（仅 `Log.d/v`，默认关闭） | — | — | — | 循环 + `System.out` + 已判断级别时不报 |
| jp-sleep-polling sleep 轮询 | — | — | — | — | — | — | `BusyWait` | — | Kotlin |
| jp-finalize finalize | `FinalizeOnlyCallsSuperFinalize` 等 finalize 系列 | `FI_*` | `Finalize` | — | — | — | `FinalizeDeclaration` | `NoFinalizer` | Kotlin `protected fun finalize()` |
| jp-expensive-alloc-hot 循环内昂贵分配 | `AvoidInstantiatingObjectsInLoops`（任何 `new`，噪声大） | `DMI_RANDOM_USED_ONLY_ONCE`（部分） | — | — | `DrawAllocation`（仅 `onDraw` 等） | — | `ObjectAllocationInLoop`（任何分配） | — | 只报"昂贵/可复用"类型与 ≥256 字节的常量数组，降低噪声 |

反过来，**这些工具覆盖而 jvmperf-lint 没有的**：PMD 的 `OptimizableToArrayCall`、`AvoidFileStream`、`InefficientEmptyStringCheck`、`AddEmptyString`；SpotBugs 的 `WMI_WRONG_MAP_ITERATOR`、`SIC_INNER_SHOULD_BE_STATIC`、`DM_STRING_CTOR`；detekt 的 `SpreadOperator`、`ForEachOnRange`、`UnnecessaryTemporaryInstantiation`；Android Lint 的 `DrawAllocation`、`Recycle`、`ViewHolder`；IntelliJ 的 `KeySetIterationMayUseEntrySet`、`ManualArrayCopy` 等。**推荐组合**：Java 用 Error Prone 或 PMD（CI）+ IntelliJ 检查（编辑时），Kotlin 用 detekt（打开 `CouldBeSequence`），Android 加 Android Lint；jvmperf-lint 作为不需要编译、同时覆盖 Java/Kotlin 的补充，最后用 JFR/async-profiler/JMH 确认哪些提示值得修。

### 15.4 实测：PMD 和 detekt 跑在同一批 bad 夹具上

两者都是单个小下载、不需要 Gradle 缓存，所以在本机实际跑了一遍（跑完已删除工具本体，输出保存在 `research/`）。

**PMD 7.28.0**（`pmd check --use-version java-25`，规则集 = 整个 `category/java/performance.xml` + 10 条相关规则，见 `research/pmd-ruleset-compare.xml`；完整输出 `research/pmd-on-fixtures.txt`）在 15 个 Java bad 夹具上：

| 夹具 | PMD 报告 | jvmperf-lint |
|---|---|---|
| jp-string-concat-hot | `UseStringBufferForStringAppends` | ✅ |
| jp-legacy-synchronized-type（规则已移除） | `ReplaceVectorWithList` ×2、`UseArrayListInsteadOfVector`、`ReplaceHashtableWithMap` ×2 | ✅ |
| jp-finalize | `FinalizeOnlyCallsSuperFinalize` | ✅ |
| jp-expensive-alloc-hot | `AvoidInstantiatingObjectsInLoops` ×3 | ✅ |
| jp-exception-control-flow | 只有 `EmptyCatchBlock`（与性能无关的附带发现） | ✅ |
| jp-enum-key-hash-collection | 只有 `UseConcurrentHashMap`（不相关） | ✅ |
| jp-boxed-primitive-collection、jp-regex-hot、jp-format-hot、jp-unpresized-collection、jp-boxed-stream、jp-many-boolean-fields（规则已移除）、jp-android-sparse-array、jp-log-hot、jp-sleep-polling | 无 | ✅ |

在 good 夹具上 PMD 报了 2 处：`good/jp-expensive-alloc-hot.java` 中按天数分配的 `new int[d.getDayOfMonth()]`（`AvoidInstantiatingObjectsInLoops`），`good/jp-enum-key-hash-collection.java` 中普通的 `HashMap<String,String>` 字段（`UseConcurrentHashMap`）。也就是说：PMD 在 Java 侧与我们重叠 4 条规则（jp-string-concat-hot/008/019/020），`AvoidInstantiatingObjectsInLoops` 比 jp-expensive-alloc-hot 宽得多（任何 `new` 都报）；注意 PMD 的 performance 规则集**没有**循环内正则检查（SpotBugs 和 Sonar 有）。

**detekt 1.23.8**（`detekt-cli-1.23.8-all.jar`，JDK 21 运行；默认配置 + 启用 `CouldBeSequence`，关闭 `MagicNumber`/`MatchingDeclarationName` 两条风格噪声；`--classpath kotlin-stdlib-1.9.22.jar` 做类型解析；完整输出 `research/detekt-on-fixtures.txt`）在 19 个 Kotlin bad 夹具上：

| 夹具 | detekt 报告 | jvmperf-lint |
|---|---|---|
| jp-boxed-primitive-collection.kt | `ArrayPrimitive` ×2（只针对 `Array<Long>`/`arrayOf(1L)`；`List<Int>`、`HashMap<Int,Int>` 未报） | ✅（3 处） |
| jp-collection-chain.kt | `CouldBeSequence`（只报了 3 步的 `pipeline`；2 步的 `map.filter.firstOrNull` 低于默认阈值） | ✅（2 处） |
| jp-exception-control-flow.kt / jp-finalize.kt | 只有 `EmptyCatchBlock` / `EmptyFunctionBlock`（附带发现） | ✅ |
| 其余 15 个（含 jp-value-class-boxing value class 装箱、jp-lambda-to-non-inline-hot、jp-lazy-default-mode、jp-data-copy-hot、jp-string-concat-hot Kotlin 拼接、jp-regex-hot Kotlin 正则等） | 无 | ✅ |

good 夹具上 detekt 只报了一处 `EmptyFunctionBlock`（`close() {}`）。为了确认 detekt 的规则本身工作正常，另用 `research/detekt-probe.kt` 验证了 `ForEachOnRange`、`SpreadOperator`、`CouldBeSequence` 都能触发（`research/detekt-probe-out.txt`）——这三条中前两条是 jvmperf-lint 没有的。备注：用 kotlinc 2.4.21 自带的 stdlib 做类型解析时 `CouldBeSequence` 没有触发，换成 1.9.22 的 stdlib 并在配置里显式启用后触发；detekt 1.23.x 内置的是 Kotlin 2.0.21 编译器。

**Android Lint**（Android SDK cmdline-tools 自带的 `lint` 8.2.0，无 Gradle 项目，`--sources` 模式）：在一个探针文件上 `LogConditional`（需 `--enable`）与 `UseValueOf` 正常触发，但 `UseSparseArrays` 对 `new HashMap<Integer, String>()` 没有报告——很可能是独立 CLI 模式缺少 AGP 提供的项目模型，所以**这里不对 Android Lint 的覆盖率下结论**（`research/android-lint-probe.txt`）。

**没有实际运行的**：SpotBugs（需要先编译出 .class，且 Kotlin 字节码误报多）、Error Prone（需要接入 javac 插件路径）、SonarQube（需要服务器）、IntelliJ（需要 IDE 安装）、OpenRewrite（需要 Maven/Gradle 插件与依赖缓存）、Checkstyle（无性能规则）、ktlint（无性能规则）。这些工具的映射基于其官方文档。

### 15.5 证据门槛与 HotSpot 对照

规则必须同时有 `evidence/<RULE>.md` 和 `evidence/<RULE>.jsonl`（见 [`docs/evidence-policy.md`](../evidence-policy.md)），才可能升到 **error**；在此之前，lint 的发现只是供人复查的提示。按当前的默认级别，**error** 共 8 条：jp-string-concat-hot、jp-boxed-stream、jp-enum-key-hash-collection、jp-data-copy-hot、jp-baos-tobytearray-copy、jp-hot-payload-copy、jp-client-factory-recreate、jp-string-intern-hot。另有 11 条规则有 JSONL 但默认低于 error：**hint** 为 jp-value-class-boxing、jp-non-static-field-updater；**off** 为 jp-boxed-primitive-collection、jp-regex-hot、jp-format-hot、jp-unpresized-collection、jp-exception-control-flow、jp-collection-chain、jp-lambda-to-non-inline-hot、jp-log-hot、jp-expensive-alloc-hot。其余 10 条只有 md 占位（多数需要 ART 或真机）：jp-lazy-default-mode、jp-android-sparse-array、jp-sleep-polling、jp-finalize、jp-hot-heavy-alloc、jp-hot-format-log、jp-hot-system-call、jp-bitmap-decode-no-reuse、jp-hot-post-lambda、jp-ui-text-append。

交叉验证：`scripts/run-static-vs-hotspot.sh` 的输出写在 `research/benches/`。**静态 lint 不等于 HotSpot 的判断**：不能只看源码就断言 C2 的编译层级或逃逸分析失败，也不要用 PrintCompilation 的行数当作“一致/不一致”的判据。

---

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

## 参考资料

**OpenJDK / Java**
- JDK 25 / 26 / 27 项目页：<https://openjdk.org/projects/jdk/25/> · <https://openjdk.org/projects/jdk/26/> · <https://openjdk.org/projects/jdk/27/>
- JEP 254 Compact Strings、192 String Dedup、280 Indify String Concat、142 @Contended、318 Epsilon、444 虚拟线程、450/519/534 紧凑对象头、454 FFM、474/490 ZGC、483/514/515/516 AOT、491 虚拟线程不钉住、506 Scoped Values、508/529/537 Vector API、509 JFR CPU 时间采样、521 分代 Shenandoah、522/523 G1：<https://openjdk.org/jeps/0>
- HotSpot GC 调优指南：<https://docs.oracle.com/en/java/javase/25/gctuning/>
- Java SE 25 API：<https://docs.oracle.com/en/java/javase/25/docs/api/>
- Aleksey Shipilёv, JVM Anatomy Quarks：<https://shipilev.net/jvm/anatomy-quarks/>
- OpenJDK Wiki CompressedOops：<https://wiki.openjdk.org/display/HotSpot/CompressedOops>

**Kotlin**
- Kotlin 2.0 / 2.4 新特性：<https://kotlinlang.org/docs/whatsnew20.html> · <https://kotlinlang.org/docs/whatsnew24.html>
- Inline value classes：<https://kotlinlang.org/docs/inline-classes.html>；Inline functions：<https://kotlinlang.org/docs/inline-functions.html>；Sequences：<https://kotlinlang.org/docs/sequences.html>

**Android**
- ART：<https://source.android.com/docs/core/runtime>；R8：<https://developer.android.com/build/shrink-code>；Baseline Profiles：<https://developer.android.com/topic/performance/baselineprofiles/overview>
- Android Lint 检查列表：<https://googlesamples.github.io/android-custom-lint-rules/checks/index.md.html>

**库与工具**
- fastutil <https://fastutil.di.unimi.it/> · Eclipse Collections <https://eclipse.dev/collections/> · androidx.collection <https://developer.android.com/jetpack/androidx/releases/collection>
- JOL <https://github.com/openjdk/jol> · JMH <https://github.com/openjdk/jmh> · async-profiler <https://github.com/async-profiler/async-profiler> · JFR API <https://docs.oracle.com/en/java/javase/25/jfapi/>
- GraalVM Native Image：<https://www.graalvm.org/jdk25/reference-manual/native-image/>
- 静态分析：PMD <https://pmd.github.io/> · SpotBugs <https://spotbugs.github.io/> · find-sec-bugs <https://find-sec-bugs.github.io/> · Error Prone <https://errorprone.info/> · detekt <https://detekt.dev/> · ktlint <https://github.com/pinterest/ktlint> · Sonar <https://rules.sonarsource.com/java/> · Checkstyle <https://checkstyle.org/> · IntelliJ Inspectopedia <https://www.jetbrains.com/help/inspectopedia/> · OpenRewrite <https://docs.openrewrite.org/>
- tree-sitter：<https://tree-sitter.github.io/tree-sitter/> · tree-sitter-java <https://github.com/tree-sitter/tree-sitter-java> · tree-sitter-kotlin <https://github.com/fwcd/tree-sitter-kotlin>
