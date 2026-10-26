# Java and Kotlin Performance Guide: Less Memory, More Throughput

> Target versions: **JDK 25** (Temurin 25.0.4.1 on the measurement machine) and **Kotlin 2.4** (kotlinc 2.4.21). Differences in JDK 21, 26, and 27 and in Android's ART runtime are called out where relevant.
> Last reviewed: 2026-10-21.
>
> - Every code sample comes from a standalone file under `examples/`. The Java samples were compiled with `javac --release 25` and run with self-checks; Kotlin samples were compiled with `kotlinc 2.4.21 -jvm-target 25` and run with self-checks. Android samples were compiled against `android-34/android.jar`. Logs are in `research/*-check.log`. Files under `research/` that this guide names (`*.txt`, `*.log`, `bench-results/`, `benches/`) are local run output and are not committed.
> - Values marked **Measured locally** were measured with JOL 0.17 on x86_64 Linux with 8 cores, JDK 25.0.4.1, G1, and compressed pointers enabled. Raw output is in `research/jol-jdk25.txt`, `research/jol-kotlin-jdk25.txt`, `research/ea-probe.txt`, and `research/jvm-flags-jdk25.txt`. Results vary across JDKs, pointer settings, and ART.
> - This guide does not invent speedup numbers. Use the JMH template in Chapter 14 to measure on your machine.
> - Each section links to its sources and explains when its recommendations do not apply.

## Contents

- [0. Version notes](#0-version-notes)
- [1. Method: estimate, then measure](#1-method-estimate-then-measure)
- [2. Object size: headers, compressed references, and compact headers](#2-object-size-headers-compressed-references-and-compact-headers)
- [3. Boxing and primitive collections](#3-boxing-and-primitive-collections)
- [4. Case study: memory used by a hybrid car](#4-case-study-memory-used-by-a-hybrid-car)
- [5. Data layout: primitive arrays, SoA, capacity, and EnumMap](#5-data-layout-primitive-arrays-soa-capacity-and-enummap)
- [6. Strings](#6-strings)
- [7. Kotlin-specific advice](#7-kotlin-specific-advice)
- [8. Off-heap memory and I/O](#8-off-heap-memory-and-io)
- [9. Helping the JIT: escape analysis, inlining, intrinsics, and Vector API](#9-helping-the-jit-escape-analysis-inlining-intrinsics-and-vector-api)
- [10. Concurrency: false sharing, virtual threads, and object pools](#10-concurrency-false-sharing-virtual-threads-and-object-pools)
- [11. Garbage collection](#11-garbage-collection)
- [12. Android and ART](#12-android-and-art)
- [13. GraalVM Native Image](#13-graalvm-native-image)
- [14. Measurement tools: JMH, JFR, async-profiler, and JOL](#14-measurement-tools-jmh-jfr-async-profiler-and-jol)
- [15. jvmperf-lint: find patterns automatically](#15-jvmperf-lint-find-patterns-automatically)
- [16. Quick reference](#16-quick-reference)
- [References](#references)

---

## 0. Version notes

| Version | Changes relevant to this guide |
|---|---|
| JDK 21 (previous LTS) | Virtual threads finalized (JEP 444); generational ZGC introduced (JEP 439, enabled with `-XX:+ZGenerational`). |
| JDK 22 | Foreign Function & Memory API (`MemorySegment`/`Arena`) finalized (JEP 454). |
| JDK 23 | Generational mode became the default for ZGC (JEP 474). |
| JDK 24 | Compact object headers preview (JEP 450); non-generational ZGC removed (JEP 490); `synchronized` no longer pins virtual threads (JEP 491); AOT class-loading cache (JEP 483). |
| **JDK 25 (LTS)** | Compact object headers finalized but **disabled by default** (JEP 519, `-XX:+UseCompactObjectHeaders`); generational Shenandoah finalized (JEP 521); Vector API incubator, 10th round (JEP 508); Stable Values preview (JEP 502); simplified AOT commands and method profiles (JEP 514/515); JFR CPU-time sampling experimental (JEP 509). |
| JDK 26 (2026-03) | G1 reduces synchronization to improve throughput (JEP 522); AOT object caching available with any GC (JEP 516); Stable Values renamed Lazy Constants (JEP 526, preview); Vector API incubator, 11th round. |
| JDK 27 (2026-09, non-LTS) | **Compact object headers enabled by default** (JEP 534); G1 is the default GC in all environments (JEP 523); Vector API incubator, 12th round (JEP 537, no API change). |
| JDK 28 (planned 2027-03) | Valhalla value classes (JEP 401) are expected to enter the mainline as a preview, according to InfoQ; the Vector API is expected to move from incubator to preview later. |
| Kotlin 2.0 | K2 compiler; lambdas use `invokedynamic` by default (`-Xlambdas=indy`). |
| Kotlin 2.4 (2026-06, current 2.4.21) | Context parameters and other features stabilized; Java 26 target supported; `-language-version 1.9` can no longer select K1. |
| Android | ART is not HotSpot: it has no C2 compiler or compressed-reference switch (references are already 32-bit), and uses 8-byte object headers. The default GC is Concurrent Mark Compact (CMC); Android 16 QPR2 adds generational CMC. See Chapter 12. |

Sources: [JDK 25](https://openjdk.org/projects/jdk/25/) · [JDK 26](https://openjdk.org/projects/jdk/26/) · [JDK 27](https://openjdk.org/projects/jdk/27/) · [JEP 534](https://openjdk.org/jeps/534) · [InfoQ: Java 27](https://www.infoq.com/news/2026/09/java27-released/) · [Kotlin 2.0](https://kotlinlang.org/docs/whatsnew20.html) · [Kotlin 2.4](https://kotlinlang.org/docs/whatsnew24.html) · [Kotlin release history](https://kotlinlang.org/docs/releases.html)

---

## 1. Method: estimate, then measure

1. **Estimate first.** JVM memory for an object is roughly its header, fields, and alignment padding, plus every object it references. Chapter 2 gives formulas and local measurements so you can estimate the cost of a million objects before changing code.
2. **Measure next.** Use JOL (`ClassLayout`/`GraphLayout`) for object sizes; JMH `-prof gc` and `gc.alloc.rate.norm`, or `ThreadMXBean.getThreadAllocatedBytes`, for allocation rates; async-profiler or JFR for CPU hotspots; and JMH for throughput and latency. Do not wrap a loop in `System.nanoTime()` and call it a benchmark: JIT warmup, dead-code elimination, and constant folding can invalidate the result.
3. **Optimize hotspots only.** Bit-packing a configuration object created a few dozen times is usually wasted effort. Replacing a `List<Integer>` with ten million entries by an `int[]` can make a large difference (see the measurements in Chapter 3).
4. **Measure again after the change.** Keep the benchmark and its correctness checks.

Chapter 14 explains how to use the measurement tools.

---

