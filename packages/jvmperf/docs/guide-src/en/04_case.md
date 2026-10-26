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

**Evidence (local):** JMH 1.37 on JDK 25 (`J26_RegexCompile`) splits N lines on `\\s+` — `Pattern.compile` inside the loop vs `static final Pattern` (`-prof gc`). JSONL: `research/bench-results/J26_RegexCompile.jsonl` (re-run before citing).

For a one-off script or configuration parse that runs only at startup, do not complicate the code just to avoid compiling a regular expression once.

### 6.4 String.format

`String.format` and `formatted` parse the format string on every call and are much slower than appending to a `StringBuilder`. In hot code, use a builder or a precompiled `MessageFormat` or `DateTimeFormatter` (share only immutable, thread-safe instances; `DateTimeFormatter` is safe, `SimpleDateFormat` is not). For logging, use parameterized logging APIs and check the log level.

**Evidence (local):** JMH 1.37 on JDK 25 (`J27_FormatHot`) formats a fixed `LocalDateTime` to `yyyy-MM-dd'T'HH:mm:ss` — `String.format` vs hand `StringBuilder` pads vs precompiled `DateTimeFormatter` (`-prof gc`). JSONL: `research/bench-results/J27_FormatHot.jsonl` (re-run before citing).

Sources: [JEP 254: Compact Strings](https://openjdk.org/jeps/254) · [JEP 192: String Deduplication in G1](https://openjdk.org/jeps/192) · [JDK 18 release notes](https://www.oracle.com/java/technologies/javase/18-relnote-issues.html) · [JEP 280: Indify String Concatenation](https://openjdk.org/jeps/280) · [`String.split`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/String.html#split(java.lang.String)) · [Kotlin `-Xstring-concat`](https://kotlinlang.org/docs/compiler-reference.html#xstring-concat)

---

