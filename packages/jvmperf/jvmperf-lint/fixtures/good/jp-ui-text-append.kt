import android.widget.TextView

class LogPanel(private val logText: TextView) {
    private val lines = ArrayDeque<String>()

    fun appendLog(msg: String) {
        lines.addFirst(msg)
        while (lines.size > 50) lines.removeLast()
    }

    fun flush() {
        logText.text = lines.joinToString("\n")
    }

    fun status(extra: String) {
        logText.text = (logText.text?.toString()?.substringBefore(" |") ?: "") + " | " + extra
    }
}
