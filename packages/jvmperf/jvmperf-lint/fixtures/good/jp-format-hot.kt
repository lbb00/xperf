fun render(xs: DoubleArray, sb: StringBuilder) {
    for (x in xs) sb.append(x).append(',')
    sb.append("%d items".format(xs.size))
}
fun guard(xs: Array<String>) {
    for (x in xs) {
        if (x.isEmpty()) throw IllegalStateException("bad %s".format(x))
    }
}
