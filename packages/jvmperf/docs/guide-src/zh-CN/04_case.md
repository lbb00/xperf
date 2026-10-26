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
        // jvmperf-lint: ignore jp-string-concat-in-loop -- Intentional counterexample.
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
    // jvmperf-lint: ignore jp-string-concat-in-loop -- Intentional counterexample.
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
        // jvmperf-lint: ignore jp-regex-in-loop -- Intentional counterexample.
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

