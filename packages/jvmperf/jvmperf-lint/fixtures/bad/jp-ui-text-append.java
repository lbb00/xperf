import android.widget.TextView;

class LogPanel {
    TextView tv;
    void appendLog(String msg) {
        tv.setText(tv.getText() + "\n" + msg);
    }
}
