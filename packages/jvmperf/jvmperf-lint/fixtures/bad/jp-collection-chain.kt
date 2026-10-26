fun firstBig(xs: List<Int>): Int? =
    xs.map { it * 2 }.filter { it > 10 }.firstOrNull()

fun pipeline(xs: List<String>) = xs.map { it.trim() }.filter { it.isNotEmpty() }.map { it.length }
