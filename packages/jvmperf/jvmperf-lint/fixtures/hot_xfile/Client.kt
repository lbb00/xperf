class Client(private val out: java.io.OutputStream) {
    fun start(cap: Capture) {
        cap.start(onJpeg = { jpeg -> Codec.write(out, jpeg) })
    }
}
interface Capture { fun start(onJpeg: (ByteArray) -> Unit) }
