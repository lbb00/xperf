fun chunkLog(tag: String, msg: String) {
    var i = 0
    while (i < msg.length) {
        val end = minOf(msg.length, i + 100)
        Log.println(3, tag, msg.substring(i, end))
        i = end
    }
}
// stub so fixture compiles enough for heuristic scan (no imports needed for lint)
object Log {
    fun println(level: Int, tag: String, msg: String) {}
}
