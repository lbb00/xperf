fun process(xs: IntArray, log: org.slf4j.Logger) {
    for (x in xs) log.debug("x=" + x)
}
