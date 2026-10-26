import java.io.OutputStream
import java.nio.ByteBuffer

class Codec(private val out: OutputStream) {
    // jvmperf-lint: hot
    fun sendFrame(type: Int, payload: ByteArray) {
        val buf = ByteBuffer.allocate(8 + payload.size)
        buf.putInt(type).putInt(payload.size)
        buf.put(payload)
        out.write(buf.array())
    }
}
