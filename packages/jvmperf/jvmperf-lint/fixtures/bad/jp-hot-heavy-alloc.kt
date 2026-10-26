import android.graphics.Canvas
import android.graphics.Paint
import android.view.View

class Marker(ctx: android.content.Context) : View(ctx) {
    override fun onDraw(canvas: Canvas) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawCircle(10f, 10f, 5f, p)
    }
}
