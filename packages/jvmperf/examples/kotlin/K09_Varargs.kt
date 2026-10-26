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
