import android.app.Activity;
import android.view.MotionEvent;
import android.widget.TextView;

class Screen extends Activity {
    TextView tv;
    @Override public boolean dispatchTouchEvent(MotionEvent e) {
        tv.setTranslationX(e.getX());
        return super.dispatchTouchEvent(e);
    }
}
