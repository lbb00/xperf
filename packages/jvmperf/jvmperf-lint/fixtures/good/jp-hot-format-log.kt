import android.view.MotionEvent

class Touch {
    fun onTouchEvent(e: MotionEvent): Boolean {
        if (e.actionMasked == MotionEvent.ACTION_DOWN) {
            android.util.Log.d("t", "down x=${e.x}")
        }
        return true
    }
}
