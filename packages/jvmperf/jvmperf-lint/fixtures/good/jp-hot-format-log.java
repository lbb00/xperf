import android.util.Log;
import android.view.MotionEvent;

class Touch {
    public boolean onTouchEvent(MotionEvent e) {
        if (Log.isLoggable("t", Log.DEBUG)) {
            Log.d("t", "move x=" + e.getX());
        }
        return true;
    }
    // Error helper reached from hot callback — demoted.
    public boolean onTouchEvent2(MotionEvent e) {
        if (e == null) return fail("null");
        return true;
    }
    boolean fail(String why) {
        Log.e("t", "bad " + why);
        return false;
    }
}
