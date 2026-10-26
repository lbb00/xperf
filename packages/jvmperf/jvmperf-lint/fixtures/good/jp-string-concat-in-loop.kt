fun join(parts: List<String>): String = buildString(parts.size * 8) {
    for (p in parts) append(p)
}

fun total(parts: List<String>): Int {
    var n = 0
    for (p in parts) n += p.length
    return n
}
