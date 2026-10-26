fun apply(x: Int, f: (Int) -> Int): Int = f(x)

fun sum(xs: IntArray, k: Int): Int {
    var s = 0
    for (x in xs) s += apply(x) { it * k }
    return s
}
