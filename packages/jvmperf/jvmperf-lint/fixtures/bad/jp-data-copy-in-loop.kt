data class State(val x: Int, val steps: Int)

fun run(n: Int): State {
    var s = State(0, 0)
    repeat(n) { s = s.copy(x = s.x + 1, steps = s.steps + 1) }
    return s
}
