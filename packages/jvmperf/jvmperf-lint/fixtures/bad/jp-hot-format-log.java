import android.util.Log;
import android.view.MotionEvent;

class Touch {
    public boolean onTouchEvent(MotionEvent e) {
        Log.d("t", "move x=" + e.getX());
        String s = String.format("%.2f", e.getY());
        return !s.isEmpty();
    }
}
