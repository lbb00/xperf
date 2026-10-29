// Each data class copy() allocates an object; repeated copies in a hot loop create many short-lived objects.
package k08

data class State(val x: Int, val y: Int, val steps: Int)

fun simulateCopy(n: Int): State {
    var s = State(0, 0, 0)
    // jvmperf-lint: ignore jp-data-copy-hot -- Intentional counterexample.
    repeat(n) { s = s.copy(x = s.x + 1, steps = s.steps + 1) }   // n allocations; escape analysis may not remove them.
    return s
}

// On a hot path, accumulate in locals (or a mutable helper) and construct the immutable result once.
fun simulateLocals(n: Int): State {
    var x = 0; var steps = 0
    repeat(n) { x++; steps++ }
    return State(x, 0, steps)
}

fun main() {
    check(simulateCopy(1000) == simulateLocals(1000))
    println("K08 ok")
}
