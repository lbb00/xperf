fun join(n: Int): String = buildString(n * 2) {
    for (i in 0 until n) {
        append(i)
    }
}

fun main() {
    println(join(8))
}
