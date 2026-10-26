import java.io.DataOutputStream

class Codec(private val out: DataOutputStream) {
    // jvmperf-lint: hot
    fun sendFrame(type: Int, payload: ByteArray) {
        out.writeInt(type)
        out.writeInt(payload.size)
        out.write(payload)
    }
}
