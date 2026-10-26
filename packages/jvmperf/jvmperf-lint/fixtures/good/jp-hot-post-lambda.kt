import android.graphics.Bitmap
import android.os.Handler
import android.widget.ImageView
import java.util.concurrent.atomic.AtomicReference

class Screen(private val handler: Handler, private val view: ImageView) {
    private val latest = AtomicReference<Bitmap?>(null)
    private val show = Runnable { latest.getAndSet(null)?.let(view::setImageBitmap) }

    fun start(server: Server) {
        server.listen(onFrame = { bmp ->
            if (latest.getAndSet(bmp) == null) handler.post(show)
        })
    }
}
interface Server { fun listen(onFrame: (Bitmap) -> Unit) }
