fun index(names: List<String>): Map<String, String> {
    val m = HashMap<String, String>()
    for (n in names) m.put(n, n)
    return m
}
