import android.os.Handler
import android.widget.ImageView

class Screen(private val handler: Handler, private val view: ImageView) {
    fun start(server: Server) {
        server.listen(onFrame = { bmp -> handler.post { view.setImageBitmap(bmp) } })
    }
}
interface Server { fun listen(onFrame: (android.graphics.Bitmap) -> Unit) }
