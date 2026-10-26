import android.graphics.Bitmap
import android.media.ImageReader
import java.io.ByteArrayOutputStream

class Enc(private val bmp: Bitmap, private val send: (ByteArray) -> Unit) {
    fun attach(reader: ImageReader) {
        reader.setOnImageAvailableListener({ _ ->
            val baos = ByteArrayOutputStream(256 * 1024)
            bmp.compress(Bitmap.CompressFormat.JPEG, 60, baos)
            send(baos.toByteArray())
        }, null)
    }
}
