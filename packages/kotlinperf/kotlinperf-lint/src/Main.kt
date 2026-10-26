package com.kotlinperf.lint

import java.io.File
import kotlin.system.exitProcess

enum class Sev { Off, Hint, Error }

fun parseSev(s: String): Sev? = when (s) {
    "error" -> Sev.Error
    "hint" -> Sev.Hint
    "off" -> Sev.Off
    else -> null
}

fun sevName(s: Sev) = when (s) {
    Sev.Error -> "error"
    Sev.Hint -> "hint"
    Sev.Off -> "off"
}

fun usage(code: Int): Nothing {
    System.err.println(
        """Usage: kotlinperf-lint PATH... [options]
  --format text|json
  --severity RULE=error|hint|off
  --strict-hints
  --no-fail
  --raw-paths          include test/samples (baseline dumps)"""
    )
    exitProcess(code)
}

fun main(args: Array<String>) {
    if (args.isEmpty()) usage(2)
    val rs = mutableMapOf(
        "kt-list-add-in-loop" to Sev.Off,
        "kt-string-plus-in-loop" to Sev.Off,
        "kt-println-in-loop" to Sev.Off,
            // KT004 removed 2026-10-22
    )
    var format = "text"
    var strictHints = false
    var noFail = false
    val paths = mutableListOf<String>()
    var i = 0
    while (i < args.size) {
        val a = args[i]
        when {
            a == "-h" || a == "--help" -> usage(0)
            a == "--format" -> {
                i++; if (i >= args.size) usage(2); format = args[i]
            }
            a.startsWith("--format=") -> format = a.removePrefix("--format=")
            a == "--severity" -> {
                i++; if (i >= args.size || !applySev(rs, args[i])) usage(2)
            }
            a.startsWith("--severity=") -> {
                if (!applySev(rs, a.removePrefix("--severity="))) usage(2)
            }
            a == "--strict-hints" -> strictHints = true
            a == "--no-fail" -> noFail = true
            a == "--raw-paths" -> enableReverseOpt = false
            a.startsWith("-") -> usage(2)
            else -> paths.add(a)
        }
        i++
    }
    if (paths.isEmpty()) usage(2)
    val findings = paths.flatMap { scanPath(it) }
    val (nerr, nhint) = emit(findings, rs, format)
    if (noFail) return
    if (nerr > 0 || (strictHints && nhint > 0)) exitProcess(1)
}

fun applySev(rs: MutableMap<String, Sev>, spec: String): Boolean {
    val eq = spec.indexOf('=')
    if (eq < 0) return false
    val rule = spec.substring(0, eq)
    val sev = parseSev(spec.substring(eq + 1)) ?: return false
    if (rule !in rs) return false
    rs[rule] = sev
    return true
}

fun emit(findings: List<Finding>, rs: Map<String, Sev>, format: String): Pair<Int, Int> {
    var nerr = 0
    var nhint = 0
    // Presize ArrayList for findings
    val text = ArrayList<String>(findings.size)
    val json = ArrayList<String>(findings.size)
    for (f in findings) {
        val s = rs[f.rule] ?: Sev.Hint
        if (s == Sev.Off) continue
        if (s == Sev.Error) nerr++ else nhint++
        if (format == "json") {
            json += """{"rule":"${f.rule}","severity":"${sevName(s)}","path":"${f.path}","line":${f.line},"message":"${f.message}"}"""
        } else {
            text += "${f.path}:${f.line}: ${sevName(s)} ${f.rule}: ${f.message}"
        }
    }
    if (format == "json") {
        println("[" + json.joinToString(",") + "]")
    } else {
        if (text.isNotEmpty()) println(text.joinToString("\n"))
        val shown = nerr + nhint
        if (shown > 0) System.err.println("$shown finding(s) ($nerr error, $nhint hint)")
        else System.err.println("ok")
    }
    return nerr to nhint
}
