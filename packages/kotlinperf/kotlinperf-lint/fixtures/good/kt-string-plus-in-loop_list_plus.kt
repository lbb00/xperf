fun goodPath(n: Int): String {
    val path = ArrayList<String>(n.coerceAtLeast(0))
    var cur = n
    while (cur > 0) {
        path += "|node$cur"
        cur--
    }
    return path.joinToString("")
}

fun goodSizes(workers: List<Int>): String {
    val queueSizes = ArrayList<String>(workers.size)
    for (q in workers) {
        queueSizes += q.toString() + "b"
    }
    return queueSizes.toString()
}
