import android.graphics.Canvas
import android.graphics.Paint
import android.view.View

class Marker(ctx: android.content.Context) : View(ctx) {
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)

    override fun onDraw(canvas: Canvas) {
        canvas.drawCircle(10f, 10f, 5f, p)
    }
}
