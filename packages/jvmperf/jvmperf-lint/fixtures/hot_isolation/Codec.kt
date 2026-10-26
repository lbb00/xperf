import java.io.ByteArrayOutputStream

object Codec {
    fun encode(payload: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(payload)
        return out.toByteArray()
    }
}
