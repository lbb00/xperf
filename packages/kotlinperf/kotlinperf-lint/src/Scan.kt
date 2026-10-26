package com.kotlinperf.lint

import java.io.File

data class Finding(val rule: String, val path: String, val line: Int, val message: String)

private val MSG = mapOf(
    "kt-list-add-in-loop" to "list alloc / add in loop; prefer capacity or reuse",
    "kt-string-plus-in-loop" to "string += in loop; prefer buildString / StringBuilder",
    "kt-println-in-loop" to "println in loop; gate or buffer",
    // KT004 removed 2026-10-22 — see evidence/_removed/
)

/** When false (--raw-paths), noise path skips + heuristics off for baseline dumps. */
var enableReverseOpt: Boolean = true

private fun isKt(f: File) = f.extension == "kt"

private val ALWAYS_SKIP = setOf(".git", "fixtures", "build", "node_modules", "vendor", ".gradle", ".idea")
private val NOISE_SKIP = setOf(
    "test", "tests", "androidTest", "benchmarks", "benchmark", "bench",
    "samples", "sample", "examples", "example", "docs", "doc", "testdata", "jvmTest", "commonTest", "nativeTest",
    "test-utils", "testing-support", "okhttp-testing-support", "rules-integration-tests",
    "okcurl", "guide", "integration-testing",
)

private fun skipDir(name: String): Boolean {
    if (name in ALWAYS_SKIP) return true
    return enableReverseOpt && name in NOISE_SKIP
}

private fun pathLooksTestish(path: String): Boolean {
    val s = path.replace('\\', '/')
    return "/test/" in s || "/tests/" in s || "/androidTest/" in s ||
        "/benchmarks/" in s || "/samples/" in s || "/examples/" in s ||
        "/test-utils/" in s || "/testing-support/" in s || "/okhttp-testing-support/" in s ||
        "/rules-integration-tests/" in s || "/okcurl/" in s || "/guide/" in s ||
        "/integration-testing/" in s ||
        s.endsWith("Test.kt") || s.endsWith("Tests.kt") || s.contains("/src/test/")
}

private fun stripLineComment(s: String): String {
    val out = StringBuilder(s.length)
    var inStr = false
    var i = 0
    while (i < s.length) {
        val c = s[i]
        if (inStr) {
            out.append(c)
            if (c == '\\' && i + 1 < s.length) {
                out.append(s[i + 1]); i += 2; continue
            }
            if (c == '"') inStr = false
            i++; continue
        }
        if (c == '"') { inStr = true; out.append(c); i++; continue }
        if (c == '/' && i + 1 < s.length && s[i + 1] == '/') break
        out.append(c); i++
    }
    return out.toString()
}

private fun kt003Signal(code: String, path: String): Boolean {
    if (!Regex("""(?<![.\w])println\s*\(""").containsMatchIn(code)) return false
    if (!enableReverseOpt) return true
    val base = File(path).name
    if (base.contains("Debug", ignoreCase = true) || base.contains("Demo", ignoreCase = true)) return false
    if (base.contains("Log", ignoreCase = true)) return false
    if (code.contains("DEBUG", ignoreCase = true)) return false
    return true
}

private fun kt002StringPlus(code: String): Boolean {
    if (!code.contains("+=")) return false
    if (!(code.contains("\"") || code.contains("'"))) return false
    val m = Regex("""\b([A-Za-z_]\w*)\s*\+=""").find(code) ?: return false
    val lhs = m.groupValues[1]
    if (!enableReverseOpt) return true
    val collectionish = Regex(
        """(?i)^(path|paths|list|lists|items|queue|queues|sizes|queueSizes|keys|values|parts|chunks|tokens|rows|cols|xs|ys)$"""
    )
    val stringy = Regex("""(?i)^(s|str|string|msg|message|text|txt|sb|builder|name|line|outStr|resultStr|accStr)$""")
    if (stringy.containsMatchIn(lhs)) return true
    if (collectionish.containsMatchIn(lhs)) return false
    if (lhs.endsWith("List", true) || lhs.endsWith("Sizes", true) || lhs.endsWith("Set", true)) return false
    return true
}



fun scanFile(path: String): List<Finding> {
    if (enableReverseOpt && pathLooksTestish(path)) return emptyList()
    val file = File(path)
    val lines = try { file.readLines() } catch (_: Exception) { return emptyList() }
    val out = ArrayList<Finding>(16)
    var depth = 0
    var inLoop = 0
    for ((idx, raw) in lines.withIndex()) {
        val lineNo = idx + 1
        val code = stripLineComment(raw)
        val trimmed = code.trimStart()
        val inDoc = trimmed.startsWith("*") || trimmed.startsWith("/*") || trimmed.startsWith("*/")
        val opens = code.count { it == '{' }
        val closes = code.count { it == '}' }


        val loopHere = !inDoc && (Regex("""\b(for|while)\b""").containsMatchIn(code) ||
            code.contains(".forEach") || code.contains("repeat("))
        if (loopHere) {
            inLoop = depth + 1
        }
        if (!inDoc && inLoop > 0 && depth >= inLoop) {
            if (Regex("""\b(mutableListOf|listOf|arrayListOf)\s*(?:<[^>]*>)?\s*\(""").containsMatchIn(code) ||
                Regex("""\bArrayList\s*\(\s*\)""").containsMatchIn(code)
            ) {
                val weak = enableReverseOpt && (
                    (Regex("""\blistOf\s*\(\s*\)""").containsMatchIn(code) &&
                        !code.contains("mutableListOf") && !code.contains("arrayListOf") &&
                        !code.contains("ArrayList")) ||
                    Regex("""\blistOf\s*\(\s*"[^"]*"(\s*,\s*"[^"]*")*\s*\)""").containsMatchIn(code) ||
                    Regex("""=\s*mutableListOf\s*(?:<[^>]*>)?\s*\(\s*\)""").containsMatchIn(code) &&
                        (code.contains("== null") || code.contains("isEmpty()") || code.contains("if ("))
                )
                if (!weak) out.add(Finding("kt-list-add-in-loop", path, lineNo, MSG.getValue("kt-list-add-in-loop")))
            }
            if (kt002StringPlus(code)) {
                out.add(Finding("kt-string-plus-in-loop", path, lineNo, MSG.getValue("kt-string-plus-in-loop")))
            }
            if (kt003Signal(code, path)) {
                out.add(Finding("kt-println-in-loop", path, lineNo, MSG.getValue("kt-println-in-loop")))
            }
            // KT004 removed 2026-10-22 — id tombstoned
        }
        depth += opens - closes
        if (depth < 0) depth = 0
        if (inLoop > 0 && depth < inLoop) {
            inLoop = 0
        }
    }
    return out
}

fun scanPath(root: String): List<Finding> {
    val f = File(root)
    if (f.isFile) return if (isKt(f)) scanFile(f.path) else emptyList()
    if (!f.isDirectory) return emptyList()
    val files = mutableListOf<File>()
    f.walkTopDown()
        .onEnter { dir -> !skipDir(dir.name) }
        .filter { it.isFile && isKt(it) }
        .forEach { files.add(it) }
    return files.flatMap { scanFile(it.path) }
}
