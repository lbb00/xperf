import android.content.Context
import android.util.DisplayMetrics
import android.view.WindowManager

object Feedback {
    private var width = 0

    fun refresh(context: Context) {
        val m = DisplayMetrics()
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        wm.defaultDisplay.getRealMetrics(m)
        width = m.widthPixels
    }

    fun onTouch(nx: Float) {
        use(nx * width)
    }
    private fun use(x: Float) = x
}
