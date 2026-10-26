// jp-value-class-boxing value-class boxing: nullable / Array / List force boxing of @JvmInline value class.
package k15

import java.lang.management.ManagementFactory
import com.sun.management.ThreadMXBean
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.time.OffsetDateTime
import java.time.ZoneId

@JvmInline
value class UserId(val raw: Int)

private data class Sample(val name: String, val nsPerOp: Double, val allocBPerOp: Double, val n: Int)

fun main(args: Array<String>) {
    val n = 10_000
    // smoke
    check(sumPrimitive(n) == sumBoxedList(n))

    if (!args.contains("--bench")) {
        println("K15 ok")
        return
    }
    val outPath = args.dropWhile { it != "--bench" }.drop(1).firstOrNull()
        ?: (System.getenv("JMH_RESULTS_DIR")?.let { "$it/K15_ValueClassBoxing.jsonl" }
            ?: "bench-results/K15_ValueClassBoxing.jsonl")

    val bean = ManagementFactory.getThreadMXBean() as ThreadMXBean
    check(bean.isThreadAllocatedMemorySupported)
    bean.isThreadAllocatedMemoryEnabled = true

    val warm = 50
    val reps = 300
    repeat(warm) {
        sumPrimitive(n)
        sumBoxedList(n)
        sumBoxedArray(n)
    }
    System.gc()
    Thread.sleep(50)

    val samples = listOf(
        measure("sumPrimitive_intArray", n, reps, bean) { sumPrimitive(n) },
        measure("sumBoxedList_UserId", n, reps, bean) { sumBoxedList(n) },
        measure("sumBoxedArray_UserId", n, reps, bean) { sumBoxedArray(n) },
    )

    val jdk = System.getProperty("java.runtime.version") ?: System.getProperty("java.version")
    val ts = OffsetDateTime.now(ZoneId.of("Asia/Shanghai")).toString()
    val sb = StringBuilder()
    for (s in samples) {
        sb.append('{')
            .append("\"name\":\"K15_ValueClassBoxing.").append(s.name).append("[n=").append(s.n).append("]\",")
            .append("\"ns_per_op\":").append("%.3f".format(s.nsPerOp)).append(',')
            .append("\"alloc_b_per_op\":").append("%.3f".format(s.allocBPerOp)).append(',')
            .append("\"n\":").append(s.n).append(',')
            .append("\"jdk_version\":\"").append(jdk).append("\",")
            .append("\"jvm_args\":\"-XX:+UseCompactObjectHeaders\",")
            .append("\"os\":\"linux\",\"cpu_arch\":\"amd64\",\"cpu_model\":\"emeraldrapids\",")
            .append("\"timestamp\":\"").append(ts).append("\",")
            .append("\"meter\":\"ThreadMXBean.getThreadAllocatedBytes\"")
            .append("}\n")
    }
    Files.writeString(Path.of(outPath), sb.toString(), StandardCharsets.UTF_8)
    println("wrote $outPath")
    samples.forEach { println("${it.name}: ${it.nsPerOp} ns/op, ${it.allocBPerOp} B/op") }
}

fun sumPrimitive(n: Int): Int {
    val a = IntArray(n) { it }
    var s = 0
    for (v in a) s += v
    return s
}

fun sumBoxedList(n: Int): Int {
    val list = ArrayList<UserId>(n)
    for (i in 0 until n) list.add(UserId(i))
    var s = 0
    for (u in list) s += u.raw
    return s
}

fun sumBoxedArray(n: Int): Int {
    val a = Array(n) { UserId(it) }
    var s = 0
    for (u in a) s += u.raw
    return s
}

private fun measure(name: String, n: Int, reps: Int, bean: ThreadMXBean, body: () -> Any): Sample {
    val tid = Thread.currentThread().threadId()
    val t0 = System.nanoTime()
    val a0 = bean.getThreadAllocatedBytes(tid)
    var sink = 0
    repeat(reps) { sink += body().hashCode() }
    val a1 = bean.getThreadAllocatedBytes(tid)
    val t1 = System.nanoTime()
    if (sink == Int.MIN_VALUE) println("sink")
    return Sample(name, (t1 - t0).toDouble() / reps, (a1 - a0).toDouble() / reps, n)
}
