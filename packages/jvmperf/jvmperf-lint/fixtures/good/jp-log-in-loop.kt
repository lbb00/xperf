fun dump(xs: IntArray) {
    for (x in xs) println(x) // diagnostic method + stdio default-off
}

fun process(xs: IntArray, log: org.slf4j.Logger) {
    for (x in xs) println(x) // stdio default-off
    for (x in xs) {
        if (log.isDebugEnabled) log.debug("x=" + x)
    }
}
