import android.view.MotionEvent

class Touch {
    fun onTouchEvent(e: MotionEvent): Boolean {
        android.util.Log.d("t", "move x=${e.x}")
        val s = "%.2f".format(e.y)
        return s.isNotEmpty()
    }
}
