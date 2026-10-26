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
    // jvmperf-lint: ignore jp-data-copy-in-loop -- Intentional counterexample.
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

