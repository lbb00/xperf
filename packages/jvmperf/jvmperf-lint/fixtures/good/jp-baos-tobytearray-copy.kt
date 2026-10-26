import android.graphics.Bitmap
import android.media.ImageReader
import java.io.ByteArrayOutputStream
import java.io.OutputStream

class Enc(private val bmp: Bitmap, private val out: OutputStream) {
    private val baos = ByteArrayOutputStream(256 * 1024)

    fun attach(reader: ImageReader) {
        reader.setOnImageAvailableListener({ _ ->
            baos.reset()
            bmp.compress(Bitmap.CompressFormat.JPEG, 60, baos)
            baos.writeTo(out)
        }, null)
    }
}
