class JpManyBooleanFields {
    static final int VISIBLE = 1, ENABLED = 1 << 1, SELECTED = 1 << 2, DIRTY = 1 << 3;
    int flags;
    boolean visible() { return (flags & VISIBLE) != 0; }
}

// Components such as Activity and Service have few instances; packing their booleans is not worthwhile.
class Activity {}
class MainActivity extends Activity {
    boolean a, b, c, d;
}

// Process singleton / Options / Config — demoted.
class Server {
    boolean started, stopping, failed, dumping;
}
class HttpClientOptions {
    boolean keepAlive, pipelining, tryUseCompression, verifyHost;
}
enum Mode {
    ;
    boolean a, b, c, d;
}
class FeatureBuilder {
    boolean x, y, z, w;
}

// Process-few client / provider / mock / *Info — demoted
class HttpClient {
    boolean started, stopped, failed, dumping;
}
class ObjectWriterProvider {
    boolean a, b, c, d;
}
class MockResponse {
    boolean a, b, c, d;
}
class BeanInfo {
    boolean a, b, c, d;
}
