private val DIGITS = Regex("\\d+")

fun count(lines: List<String>): Int {
    var n = 0
    for (l in lines) {
        if (DIGITS.containsMatchIn(l)) n++
        n += l.split(",").size
    }
    return n
}
