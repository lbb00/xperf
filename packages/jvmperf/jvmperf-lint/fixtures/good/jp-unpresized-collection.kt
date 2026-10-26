fun index(names: List<String>): Map<String, String> {
    val m = HashMap<String, String>(names.size * 2)
    for (n in names) m.put(n, n)
    return m
}
fun tiny(): List<String> {
    val xs = ArrayList<String>()
    for (i in 0 until 3) xs.add("x")
    return xs
}
class Dump {
    override fun toString(): String {
        val sb = StringBuilder()
        for (i in 0 until 10) sb.append(i)
        return sb.toString()
    }
}
