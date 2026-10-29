// jvmperf-lint: ignore-file jp-lazy-default-mode,jp-boxed-primitive-collection
class Ignored {
    val x by lazy { 1 }
    val xs: List<Int> = listOf(1)
    fun dump(ys: IntArray) {
        for (y in ys) {
            println(y) // jvmperf-lint: ignore log-hot
        }
    }
}
