class JpManyBooleanFields(var flags: Int) {
    val visible: Boolean get() = flags and 1 != 0
    val enabled: Boolean get() = flags and 2 != 0
    var label: String = ""
}

open class AppCompatActivity
class MainActivity : AppCompatActivity() {
    private var a = false
    private var b = false
    private var c = false
    private var d = false
}

class Server {
    var started = false
    var stopping = false
    var failed = false
    var dumping = false
}

class HttpClientOptions {
    var keepAlive = false
    var pipelining = false
    var tryUseCompression = false
    var verifyHost = false
}

object AppGlobals {
    var a = false
    var b = false
    var c = false
    var d = false
}
