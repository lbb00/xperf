// Measure collection-chain vs asSequence vs imperative loop (time + allocated bytes).
// Guide §7.4. Smoke path keeps check_kotlin.sh fast; pass --bench to emit JSONL.
package k13

import java.lang.management.ManagementFactory
import com.sun.management.ThreadMXBean
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.time.OffsetDateTime
import java.time.ZoneId

fun eagerChain(data: List<Int>, take: Int): List<Int> =
    // jvmperf-lint: ignore jp-collection-chain -- Intentional counterexample for measurement.
    data.map { it * 2 }.filter { it % 3 == 0 }.take(take)

fun sequenceChain(data: List<Int>, take: Int): List<Int> =
    data.asSequence().map { it * 2 }.filter { it % 3 == 0 }.take(take).toList()

fun imperative(data: List<Int>, take: Int): List<Int> {
    val out = ArrayList<Int>(take)
    for (v in data) {
        val m = v * 2
        if (m % 3 == 0) {
            out.add(m)
            if (out.size == take) break
        }
    }
    return out
}

private data class Sample(val name: String, val nsPerOp: Double, val allocBPerOp: Double, val n: Int, val take: Int)

fun main(args: Array<String>) {
    val data = List(100_000) { it }
    val take = 5
    val e = eagerChain(data, take)
    val s = sequenceChain(data, take)
    val i = imperative(data, take)
    check(e == s && s == i)

    if (!args.contains("--bench")) {
        println("K13 ok")
        return
    }

    val outPath = args.dropWhile { it != "--bench" }.drop(1).firstOrNull()
        ?: System.getenv("K13_JSONL")
        ?: (System.getenv("JMH_RESULTS_DIR")?.let { "$it/K13_SequenceAlloc.jsonl" }
            ?: "bench-results/K13_SequenceAlloc.jsonl")

    val bean = ManagementFactory.getThreadMXBean() as ThreadMXBean
    check(bean.isThreadAllocatedMemorySupported)
    bean.isThreadAllocatedMemoryEnabled = true

    val n = 100_000
    val warm = 50
    val reps = 200
    // Warmup
    repeat(warm) {
        eagerChain(data, take)
        sequenceChain(data, take)
        imperative(data, take)
    }
    System.gc()
    Thread.sleep(50)

    val samples = listOf(
        measure("eagerChain", n, take, reps, bean) { eagerChain(data, take) },
        measure("sequenceChain", n, take, reps, bean) { sequenceChain(data, take) },
        measure("imperative", n, take, reps, bean) { imperative(data, take) },
    )

    val jdk = "${System.getProperty("java.version")} (${System.getProperty("java.vm.version")})"
    val jvmArgs = "-XX:+UseCompactObjectHeaders"
    val os = "linux"
    val arch = System.getProperty("os.arch")
    val cpu = detectCpu()
    val ts = OffsetDateTime.now(ZoneId.of("Asia/Shanghai")).toString()

    val sb = StringBuilder()
    for (sample in samples) {
        val name = "K13_SequenceAlloc.${sample.name}[n=${sample.n},take=${sample.take}]"
        sb.append('{')
        append(sb, "name", name)
        sb.append(',')
        appendNum(sb, "ns_per_op", sample.nsPerOp)
        sb.append(',')
        appendNum(sb, "alloc_b_per_op", sample.allocBPerOp)
        sb.append(',')
        appendNum(sb, "n", sample.n.toLong())
        sb.append(',')
        appendNum(sb, "take", sample.take.toLong())
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
            "K13 %s ns/op=%.1f alloc_B/op=%.1f",
            sample.name, sample.nsPerOp, sample.allocBPerOp
        ))
    }
    Files.writeString(Path.of(outPath), sb.toString(), StandardCharsets.UTF_8)
    println("K13 ok wrote $outPath")
}

private fun measure(
    name: String,
    n: Int,
    take: Int,
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
        take = take,
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
