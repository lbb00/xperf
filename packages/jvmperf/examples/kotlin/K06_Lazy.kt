// by lazy defaults to SYNCHRONIZED (with locking and an extra object); use NONE for single-threaded access.
package k06

class Config {
    // Accessed only on the main thread or another single thread:
    val parsed: Map<String, String> by lazy(LazyThreadSafetyMode.NONE) { mapOf("a" to "1") }
    // Multiple threads may access it and initialization is cheap and idempotent: PUBLICATION (may initialize more than once).
    val table: IntArray by lazy(LazyThreadSafetyMode.PUBLICATION) { IntArray(256) { it * it } }
    // Default mode: SYNCHRONIZED.
    // jvmperf-lint: ignore jp-lazy-default-mode -- Intentional counterexample.
    val heavy: String by lazy { "computed" }
}

// Each by lazy property adds a Lazy object and a lambda, which costs memory across many instances.
// For many instances, use a nullable field with a manual check or move the cache elsewhere.
class Row(private val raw: String) {
    private var cachedLen: Int = -1
    val len: Int get() { if (cachedLen < 0) cachedLen = raw.length; return cachedLen }
}

fun main() {
    val c = Config()
    check(c.parsed["a"] == "1" && c.table[3] == 9 && c.heavy == "computed")
    check(Row("abc").len == 3)
    println("K06 ok")
}
