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
