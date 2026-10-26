fun firstBig(xs: List<String>): String? =
    xs.asSequence().map { it.trim() }.filter { it.length > 10 }.firstOrNull()

fun lengths(xs: List<String>) = xs.map { it.length }
