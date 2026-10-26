import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.InputStream

class Decoder(private val input: InputStream) {
    private val opts = BitmapFactory.Options().apply { inMutable = true }

    fun loop(show: (Bitmap) -> Unit) {
        var reuse: Bitmap? = null
        while (true) {
            val bytes = ByteArray(input.read())
            opts.inBitmap = reuse
            val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts) ?: break
            reuse = bmp
            show(bmp)
        }
    }
}
