fun countInts(xs: List<String>): Int {
    var n = 0
    for (x in xs) {
        try {
            x.toInt()
            n++
        } catch (e: NumberFormatException) {
        }
    }
    return n
}
