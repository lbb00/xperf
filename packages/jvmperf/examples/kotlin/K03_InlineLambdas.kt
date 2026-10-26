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
