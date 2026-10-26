import android.content.Context
import android.util.DisplayMetrics
import android.view.WindowManager

object Feedback {
    fun onTouch(context: Context, nx: Float) {
        val m = DisplayMetrics()
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        wm.defaultDisplay.getRealMetrics(m)
        use(nx * m.widthPixels)
    }
    private fun use(x: Float) = x
}
