import java.time.format.DateTimeFormatter
private val FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd")
fun fmt(ts: List<java.time.LocalDate>): List<String> {
    val out = ArrayList<String>(ts.size)
    val buf = ByteArray(8192)
    for (t in ts) {
        out.add(t.format(FMT) + buf.size)
        val row = IntArray(t.dayOfMonth)
        out.add(row.size.toString())
    }
    return out
}
