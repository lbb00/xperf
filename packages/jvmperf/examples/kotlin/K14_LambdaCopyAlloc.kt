// Measure inline vs non-inline lambda, and data-class copy() vs locals (time + allocated bytes).
// Guide §§7.3 / 7.7. Smoke path for check_kotlin.sh; pass --bench to emit JSONL.
package k14

import java.lang.management.ManagementFactory
import com.sun.management.ThreadMXBean
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.time.OffsetDateTime
import java.time.ZoneId

data class State(val x: Int, val y: Int, val steps: Int)

inline fun repeatSumInline(n: Int, f: (Int) -> Int): Int {
    var s = 0
    for (i in 0 until n) s += f(i)
    return s
}

fun repeatSumBoxed(n: Int, f: (Int) -> Int): Int {
    var s = 0
    for (i in 0 until n) s += f(i)
    return s
}

fun simulateCopy(n: Int): State {
    var s = State(0, 0, 0)
    // jvmperf-lint: ignore jp-data-copy-hot -- Intentional counterexample for measurement.
    repeat(n) { s = s.copy(x = s.x + 1, steps = s.steps + 1) }
    return s
}

fun simulateLocals(n: Int): State {
    var x = 0
    var steps = 0
    repeat(n) { x++; steps++ }
    return State(x, 0, steps)
}

private data class Sample(val name: String, val nsPerOp: Double, val allocBPerOp: Double, val n: Int)

fun main(args: Array<String>) {
    val k = 3
    check(repeatSumInline(1000) { it * k } == repeatSumBoxed(1000) { it * k })
    check(simulateCopy(1000) == simulateLocals(1000))

    if (!args.contains("--bench")) {
        println("K14 ok")
        return
    }

    val outPath = args.dropWhile { it != "--bench" }.drop(1).firstOrNull()
        ?: System.getenv("K14_JSONL")
        ?: (System.getenv("JMH_RESULTS_DIR")?.let { "$it/K14_LambdaCopyAlloc.jsonl" }
            ?: "bench-results/K14_LambdaCopyAlloc.jsonl")

    val bean = ManagementFactory.getThreadMXBean() as ThreadMXBean
    check(bean.isThreadAllocatedMemorySupported)
    bean.isThreadAllocatedMemoryEnabled = true

    val nLambda = 10_000
    val nCopy = 10_000
    val warm = 100
    val reps = 500

    repeat(warm) {
        repeatSumInline(nLambda) { it * k }
        repeatSumBoxed(nLambda) { it * k }
        simulateCopy(nCopy)
        simulateLocals(nCopy)
    }
    System.gc()
    Thread.sleep(50)

    val samples = listOf(
        measure("repeatSumInline", nLambda, reps, bean) { repeatSumInline(nLambda) { it * k } },
        measure("repeatSumBoxed", nLambda, reps, bean) { repeatSumBoxed(nLambda) { it * k } },
        measure("simulateCopy", nCopy, reps, bean) { simulateCopy(nCopy) },
        measure("simulateLocals", nCopy, reps, bean) { simulateLocals(nCopy) },
    )

    val jdk = "${System.getProperty("java.version")} (${System.getProperty("java.vm.version")})"
    val jvmArgs = "-XX:+UseCompactObjectHeaders"
    val os = "linux"
    val arch = System.getProperty("os.arch")
    val cpu = detectCpu()
    val ts = OffsetDateTime.now(ZoneId.of("Asia/Shanghai")).toString()

    val sb = StringBuilder()
    for (sample in samples) {
        val name = "K14_LambdaCopyAlloc.${sample.name}[n=${sample.n}]"
        sb.append('{')
        append(sb, "name", name)
        sb.append(',')
        appendNum(sb, "ns_per_op", sample.nsPerOp)
        sb.append(',')
        appendNum(sb, "alloc_b_per_op", sample.allocBPerOp)
        sb.append(',')
        appendNum(sb, "n", sample.n.toLong())
        sb.append(',')
        append(sb, "jdk_version", jdk)
        sb.append(',')
        append(sb, "jvm_args", jvmArgs)
        sb.append(',')
        append(sb, "os", os)
        sb.append(',')
        append(sb, "cpu_arch", arch)
        sb.append(',')
        append(sb, "cpu_model", cpu)
        sb.append(',')
        append(sb, "timestamp", ts)
        sb.append(',')
        append(sb, "meter", "ThreadMXBean.getThreadAllocatedBytes")
        sb.append("}\n")
        println(String.format(
            "K14 %s ns/op=%.1f alloc_B/op=%.1f",
            sample.name, sample.nsPerOp, sample.allocBPerOp
        ))
    }
    Files.writeString(Path.of(outPath), sb.toString(), StandardCharsets.UTF_8)
    println("K14 ok wrote $outPath")
}

private fun measure(
    name: String,
    n: Int,
    reps: Int,
    bean: ThreadMXBean,
    body: () -> Any,
): Sample {
    val tid = Thread.currentThread().threadId()
    val t0 = System.nanoTime()
    val a0 = bean.getThreadAllocatedBytes(tid)
    var sink: Any? = null
    repeat(reps) { sink = body() }
    val a1 = bean.getThreadAllocatedBytes(tid)
    val t1 = System.nanoTime()
    check(sink != null)
    return Sample(
        name = name,
        nsPerOp = (t1 - t0).toDouble() / reps,
        allocBPerOp = (a1 - a0).toDouble() / reps,
        n = n,
    )
}

private fun detectCpu(): String {
    try {
        val info = Files.readString(Path.of("/proc/cpuinfo"))
        val fam = Regex("""cpu family\s*:\s*(\d+)""").find(info)?.groupValues?.get(1)?.toIntOrNull()
        val mod = Regex("""(?m)^model\s*:\s*(\d+)""").find(info)?.groupValues?.get(1)?.toIntOrNull()
        if (fam == 6 && mod == 207) return "emeraldrapids"
        val name = Regex("""model name\s*:\s*(.+)""").find(info)?.groupValues?.get(1)?.trim()?.replace(' ', '_')
        if (name != null) return name
    } catch (_: Exception) {
    }
    return "unknown"
}

private fun append(sb: StringBuilder, k: String, v: String) {
    sb.append('"').append(k).append("\":\"").append(v.replace("\\", "\\\\").replace("\"", "\\\"")).append('"')
}

private fun appendNum(sb: StringBuilder, k: String, v: Double) {
    sb.append('"').append(k).append("\":").append(String.format(java.util.Locale.ROOT, "%.3f", v))
}

private fun appendNum(sb: StringBuilder, k: String, v: Long) {
    sb.append('"').append(k).append("\":").append(v)
}
