fun bad(n: Int): List<List<Int>> {
    val out = ArrayList<List<Int>>()
    for (i in 0 until n) {
        val tmp = mutableListOf<Int>()
        out.add(tmp)
    }
    return out
}
