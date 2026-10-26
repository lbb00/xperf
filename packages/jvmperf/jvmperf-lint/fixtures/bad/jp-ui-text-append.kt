import android.widget.TextView

class LogPanel(private val logText: TextView) {
    fun appendLog(msg: String) {
        val cur = logText.text?.toString() ?: ""
        logText.text = (msg + "\n" + cur).take(2000)
    }
}
