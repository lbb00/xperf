data class State(val x: Int, val steps: Int)

fun run(n: Int): State {
    var x = 0
    var steps = 0
    repeat(n) {
        x++
        steps++
    }
    return State(x, steps).copy(steps = steps)
}
