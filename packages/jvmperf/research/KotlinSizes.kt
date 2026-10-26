// 用 JOL 实测 Kotlin 类型的内存占用（与 JolSizes.java 配套）。
import org.openjdk.jol.info.ClassLayout
import org.openjdk.jol.info.GraphLayout

data class HybridBools(val electric: Boolean, val benzine: Boolean, val diesel: Boolean)
data class HybridInts(val electric: Int, val benzine: Int)
@JvmInline value class FuelFlags(val bits: Byte)
class CarWithFlags(val fuels: FuelFlags)
class CarWithNullableFlags(val fuels: FuelFlags?)

fun graph(what: String, o: Any) =
    println("%-46s total=%d bytes, objects=%d".format(what, GraphLayout.parseInstance(o).totalSize(), GraphLayout.parseInstance(o).totalCount()))

fun main() {
    println("java.version=" + System.getProperty("java.version") + ", UseCompactObjectHeaders=" +
        java.lang.management.ManagementFactory.getRuntimeMXBean().inputArguments.contains("-XX:+UseCompactObjectHeaders"))
    for (c in listOf(HybridBools::class.java, HybridInts::class.java, CarWithFlags::class.java, CarWithNullableFlags::class.java))
        println("%-28s instance=%d".format(c.simpleName, ClassLayout.parseClass(c).instanceSize()))
    graph("IntArray(1000)", IntArray(1000))
    graph("Array<Int>(1000) {it+1000}", Array(1000) { it + 1000 })
    graph("List<Int>(1000) {it+1000}", List(1000) { it + 1000 })
    graph("ByteArray(1000) (每车 1 字节标志)", ByteArray(1000))
    graph("Array<FuelFlags>(1000) (装箱)", Array(1000) { FuelFlags((it % 7).toByte()) })
    graph("Array<HybridBools>(1000) 各不相同的实例", Array(1000) { HybridBools(it % 2 == 0, true, false) })
}
