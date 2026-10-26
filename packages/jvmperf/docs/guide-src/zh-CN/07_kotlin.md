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

