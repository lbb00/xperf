fun parseAll(items: List<String>): List<String> {
    var out: MutableList<String>? = null
    for (s in items) {
        if (out == null) out = mutableListOf()
        out.add(s)
    }
    return out ?: emptyList()
}

fun dropMods(parts: List<String>): List<String> {
    val mods = listOf("static", "public", "final")
    return parts.filter { it !in mods }
}
