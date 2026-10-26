fun countInts(xs: List<String>): Int {
    var n = 0
    for (x in xs) {
        if (x.toIntOrNull() != null) n++
    }
    return n
}
