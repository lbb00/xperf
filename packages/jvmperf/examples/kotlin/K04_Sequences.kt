// Use asSequence() for multi-step chains over large data or with early termination; direct operations suit small collections.
package k04

fun main() {
    val data = List(100_000) { it }
    // Collection version: map creates a 100,000-element list, filter creates another, then take returns five.
    // jvmperf-lint: ignore jp-collection-chain -- Intentional counterexample.
    val eager = data.map { it * 2 }.filter { it % 3 == 0 }.take(5)
    // Sequence version: process one element at a time and stop after five matches, with no intermediate lists.
    var mapped = 0
    val lazy = data.asSequence().map { mapped++; it * 2 }.filter { it % 3 == 0 }.take(5).toList()
    check(eager == lazy)
    check(mapped < 20)              // Only the first few elements were processed.
    // Primitive operations such as IntArray.sumOf/fold are inline and do not box values.
    val arr = IntArray(1000) { it }
    check(arr.sumOf { it.toLong() } == 499500L)
    // Sequence<Int> still boxes elements; use a loop or IntStream for numeric pipelines.
    println("K04 ok")
}
