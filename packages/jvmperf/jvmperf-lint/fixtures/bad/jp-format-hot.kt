fun render(xs: DoubleArray, sb: StringBuilder) {
    for (x in xs) sb.append("%.2f,".format(x))
}
