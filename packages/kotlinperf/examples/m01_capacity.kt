fun grow(n: Int): MutableList<Int> {
    val v = ArrayList<Int>(n)
    for (i in 0 until n) {
        v.add(i)
    }
    return v
}

fun main() {
    println(grow(8).size)
}
