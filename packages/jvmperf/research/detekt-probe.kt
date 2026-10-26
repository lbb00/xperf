fun bar(vararg xs: String) = xs.size
fun p(xs: List<Int>, a: Array<String>): Int {
    (1..10).forEach { println(it) }
    val y = xs.map { it * 2 }.filter { it > 3 }.map { it + 1 }.sum()
    return y + bar(*a)
}
