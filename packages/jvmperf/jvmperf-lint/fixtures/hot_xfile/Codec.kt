import java.nio.ByteBuffer

object Codec {
    fun write(out: java.io.OutputStream, payload: ByteArray) {
        out.write(encode(payload))
    }

    private fun encode(payload: ByteArray): ByteArray {
        val buf = ByteBuffer.allocate(12 + payload.size)
        buf.put(payload)
        return buf.array()
    }
}
