import android.graphics.BitmapFactory
import java.io.InputStream

class Decoder(private val input: InputStream) {
    fun loop(show: (android.graphics.Bitmap) -> Unit) {
        while (true) {
            val bytes = ByteArray(input.read())
            val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: break
            show(bmp)
        }
    }
}
