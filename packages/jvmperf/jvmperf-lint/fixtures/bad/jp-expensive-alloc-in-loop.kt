import java.time.format.DateTimeFormatter
fun fmt(ts: List<java.time.LocalDate>): List<String> {
    val out = ArrayList<String>(ts.size)
    for (t in ts) {
        out.add(t.format(DateTimeFormatter.ofPattern("yyyy-MM-dd")))
        val buf = ByteArray(8192)
        out.add(buf.size.toString())
    }
    return out
}
