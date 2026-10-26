// jvmperf-lint: ignore-file JpLazyDefaultMode,JpBoxedPrimitiveCollection
class Ignored {
    val x by lazy { 1 }
    val xs: List<Int> = listOf(1)
    fun dump(ys: IntArray) {
        for (y in ys) {
            println(y) // jvmperf-lint: ignore JpLogInLoop
        }
    }
}
