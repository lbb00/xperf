import android.widget.TextView;

class LogPanel {
    TextView tv;
    void appendLog(String msg) {
        tv.append("\n");
        tv.append(msg);
    }
}
