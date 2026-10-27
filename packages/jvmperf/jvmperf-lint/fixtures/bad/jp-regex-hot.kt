fun count(lines: List<String>): Int {
    var n = 0
    for (l in lines) {
        if (Regex("\\d+").containsMatchIn(l)) n++
        if (l.matches("a.*".toRegex())) n++
    }
    return n
}
