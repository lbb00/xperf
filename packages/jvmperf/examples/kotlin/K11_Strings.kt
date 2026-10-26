// Build strings with reserved capacity; avoid += concatenation in loops.
package k11

fun render(items: List<Pair<String, Int>>): String =
    buildString(items.size * 16) {                    // Estimate capacity to reduce growth.
        for ((k, v) in items) { append(k); append('='); append(v); append('\n') }
    }

fun renderSlow(items: List<Pair<String, Int>>): String {
    var s = ""
    // jvmperf-lint: ignore jp-string-concat-in-loop -- Intentional counterexample.
    for ((k, v) in items) s += "$k=$v\n"              // Copies the entire string on each iteration.
    return s
}

fun main() {
    val items = List(100) { "k$it" to it }
    check(render(items) == renderSlow(items))
    check(items.joinToString(",", limit = 2) { it.first } == "k0,k1,...")
    println("K11 ok")
}
