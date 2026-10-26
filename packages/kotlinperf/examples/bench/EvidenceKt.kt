import java.io.File
import java.io.PrintStream
import java.time.Instant
import kotlin.system.measureNanoTime

const val ROUNDS = 9
const val WARM = 5

fun median(xs: List<Double>): Double {
    val a = xs.sorted()
    val n = a.size
    val m = n / 2
    return if (n % 2 == 1) a[m] else 0.5 * (a[m - 1] + a[m])
}

fun timeMany(fn: () -> Int): Double {
    repeat(WARM) { fn() }
    System.gc()
    Thread.sleep(50)
    val samples = ArrayList<Double>(ROUNDS)
    var sink = 0
    repeat(ROUNDS) {
        System.gc()
        val ns = measureNanoTime { sink += fn() }
        samples.add(ns / 1e6)
    }
    if (sink == Int.MAX_VALUE) error("sink")
    return median(samples)
}

fun emit(dir: String, rule: String, pairs: List<Triple<String, String, Pair<Double, Int>>>) {
    val ts = Instant.now().toString()
    var lastAfter = 1.0
    val lines = ArrayList<String>()
    for ((caseName, role, msOps) in pairs) {
        val (ms, ops) = msOps
        if (role == "after") lastAfter = ms
        val ratio = ms / lastAfter
        lines += """{"rule":"$rule","case":"$caseName","role":"$role","kotlin":"${KotlinVersion.CURRENT}","jre":"${System.getProperty("java.version")}","median_ms":$ms,"ops":$ops,"ratio":$ratio,"ts":"$ts"}"""
        println("  $role $caseName $ms ratio=$ratio")
    }
    File(dir, "$rule.jsonl").writeText(lines.joinToString("\n", postfix = "\n"))
    println("wrote $dir/$rule.jsonl")
}

fun main() {
    val dir = System.getenv("EVIDENCE_DIR") ?: "../../evidence" // relative to examples/bench
    File(dir).mkdirs()
    println("kotlin ${KotlinVersion.CURRENT} jre ${System.getProperty("java.version")}")

    val n4 = System.getenv("KT004_N")?.toIntOrNull() ?: 2_000_000
    val src4 = IntArray(n4) { it }
    val before4 = timeMany {
        val out = ArrayList<Int>() // empty default capacity — matches "empty + add sized"
        for (x in src4) out.add(x)
        out.size
    }
    val after4 = timeMany {
        val out = ArrayList<Int>(src4.size)
        for (x in src4) out.add(x)
        out.size
    }
    // also mutableListOf pair (fixture wording)
    val before4b = timeMany {
        val out = mutableListOf<Int>()
        for (x in src4) out.add(x)
        out.size
    }
    emit(dir, "KT004", listOf(
        Triple("arraylist_capacity", "after", after4 to n4),
        Triple("arraylist_empty_add", "before", before4 to n4),
        Triple("arraylist_capacity_b", "after", after4 to n4),
        Triple("mutableListOf_empty_add", "before", before4b to n4),
    ))

    val n1 = System.getenv("KT001_N")?.toIntOrNull() ?: 2_000_000
    val src1 = IntArray(n1) { it }
    val before1 = timeMany {
        val out = ArrayList<Int>()
        for (x in src1) out.add(x)
        out.size
    }
    val after1 = timeMany {
        val out = ArrayList<Int>(src1.size)
        for (x in src1) out.add(x)
        out.size
    }
    emit(dir, "kt-list-add-in-loop", listOf(
        Triple("arraylist_capacity", "after", after1 to n1),
        Triple("list_add_empty", "before", before1 to n1),
    ))

    val n2 = System.getenv("KT002_N")?.toIntOrNull() ?: 30000
    val before2 = timeMany {
        var s = ""
        for (i in 0 until n2) s += i.toString()
        s.length
    }
    val after2 = timeMany {
        buildString {
            for (i in 0 until n2) append(i)
        }.length
    }
    emit(dir, "kt-string-plus-in-loop", listOf(
        Triple("buildString", "after", after2 to n2),
        Triple("string_plus", "before", before2 to n2),
    ))

    val n3 = System.getenv("KT003_N")?.toIntOrNull() ?: 20000
    val nullOut = PrintStream("/dev/null")
    val old = System.out
    System.setOut(nullOut)
    val before3 = timeMany {
        var s = 0
        for (i in 0 until n3) { println(i); s += i }
        s
    }
    val after3 = timeMany {
        var s = 0
        for (i in 0 until n3) s += i
        println(s)
        s
    }
    System.setOut(old)
    nullOut.close()
    emit(dir, "kt-println-in-loop", listOf(
        Triple("println_once", "after", after3 to n3),
        Triple("println_in_loop", "before", before3 to n3),
    ))
}
