# Java / Kotlin 极限性能指南：省内存与跑得快

> 目标版本：**JDK 25（当前 LTS，本机 Temurin 25.0.4.1）** + **Kotlin 2.4（本机 kotlinc 2.4.21）**，同时标注 JDK 21 / 26 / 27 的差异与 **Android（ART）** 的不同之处。
> 写作日期：2026-10-21。
>
> 约定：
> - 文中所有代码都来自 `examples/` 目录下的独立文件，**全部在本机编译并运行通过**（Java：`javac --release 25` + 运行自检；Kotlin：`kotlinc 2.4.21 -jvm-target 25` + 运行自检；Android：对 `android-34/android.jar` 编译）。编译日志见 `research/*-check.log`。本文提到的 `research/` 下的 `*.txt`、`*.log`、`bench-results/`、`benches/` 是本地运行输出，不入库。
> - 文中出现的字节数，凡标注 **【本机实测】** 的，都是用 JOL 0.17 在本机（x86_64 Linux，8 核，JDK 25.0.4.1，默认 G1、压缩指针开启）测得，原始输出见 `research/jol-jdk25.txt`、`research/jol-kotlin-jdk25.txt`、`research/ea-probe.txt`、`research/jvm-flags-jdk25.txt`。其他环境（不同 JDK、关闭压缩指针、ART）数字会不同。
> - 本文**不给出自己编造的加速比**。需要性能数字时请用第 14 章的 JMH 模板在你的机器上测。
> - 每节末尾给出来源链接；每个技巧都写了"什么时候不要用"。

## 目录

- [0. 版本须知](#0-版本须知)
- [1. 方法论：先估算、再测量](#1-方法论先估算再测量)
- [2. 对象有多大：对象头、压缩指针、紧凑对象头](#2-对象有多大对象头压缩指针紧凑对象头)
- [3. 装箱与原始类型集合](#3-装箱与原始类型集合)
- [4. 案例：一辆混动车在 JVM 上占多少内存](#4-案例一辆混动车在-jvm-上占多少内存)
- [5. 数据布局：原始数组、SoA、预设容量、EnumMap](#5-数据布局原始数组soa预设容量enummap)
- [6. 字符串](#6-字符串)
- [7. Kotlin 专项](#7-kotlin-专项)
- [8. 堆外内存与 I/O](#8-堆外内存与-io)
- [9. 让 JIT 帮你：逃逸分析、内联、intrinsic、Vector API](#9-让-jit-帮你逃逸分析内联intrinsicvector-api)
- [10. 并发：伪共享、虚拟线程、对象池](#10-并发伪共享虚拟线程对象池)
- [11. GC 选择与调优](#11-gc-选择与调优)
- [12. Android（ART）专项](#12-androidart专项)
- [13. GraalVM Native Image](#13-graalvm-native-image)
- [14. 度量工具：JMH、JFR、async-profiler、JOL](#14-度量工具jmhjfrasync-profilerjol)
- [15. jvmperf-lint：自动找出反模式](#15-jvmperf-lint自动找出反模式)（含 15.3 与 PMD / SpotBugs / Error Prone / detekt / Android Lint / Sonar / IntelliJ / OpenRewrite 等工具的对比）
- [16. 速查表](#16-速查表)
- [参考资料](#参考资料)

---

## 0. 版本须知

| 版本 | 与本文相关的变化 |
|---|---|
| JDK 21（上一个 LTS） | 虚拟线程正式（JEP 444）；分代 ZGC 引入（JEP 439，需 `-XX:+ZGenerational`） |
| JDK 22 | FFM API（`MemorySegment`/`Arena`）正式（JEP 454） |
| JDK 23 | 分代 ZGC 成为 ZGC 默认模式（JEP 474） |
| JDK 24 | 紧凑对象头实验版（JEP 450）；非分代 ZGC 移除（JEP 490）；`synchronized` 不再钉住虚拟线程（JEP 491）；AOT 类加载缓存（JEP 483） |
| **JDK 25（LTS）** | 紧凑对象头成为正式产品特性但**默认关闭**（JEP 519，`-XX:+UseCompactObjectHeaders`）；分代 Shenandoah 正式（JEP 521）；Vector API 第 10 轮孵化（JEP 508）；Stable Values 预览（JEP 502）；AOT 命令行简化与方法 profile（JEP 514/515）；JFR CPU 时间采样（实验，JEP 509） |
| JDK 26（2026-03） | G1 减少同步提升吞吐（JEP 522）；任意 GC 都可用 AOT 对象缓存（JEP 516）；Stable Values 改名 Lazy Constants（JEP 526，预览）；Vector API 第 11 轮孵化 |
| JDK 27（2026-09，非 LTS） | **紧凑对象头默认开启**（JEP 534）；G1 在所有环境下都是默认 GC（JEP 523）；Vector API 第 12 轮孵化（JEP 537，无 API 变化） |
| JDK 28（计划 2027-03） | Valhalla 的值类（JEP 401）以预览形式进入主线（据 InfoQ 报道），之后 Vector API 才会从孵化转为预览 |
| Kotlin 2.0 | K2 编译器；lambda 默认用 `invokedynamic` 生成（`-Xlambdas=indy`） |
| Kotlin 2.4（2026-06，当前 2.4.21） | 上下文参数等稳定；支持 Java 26 目标；不再能用 `-language-version 1.9` 回退到 K1 |
| Android | ART 不是 HotSpot：没有 C2、没有压缩指针开关（引用本来就是 32 位）、对象头 8 字节；默认 GC 为并发标记整理（CMC），Android 16 QPR2 起为分代 CMC。详见第 12 章 |

来源：[JDK 25](https://openjdk.org/projects/jdk/25/) · [JDK 26](https://openjdk.org/projects/jdk/26/) · [JDK 27](https://openjdk.org/projects/jdk/27/) · [JEP 534](https://openjdk.org/jeps/534) · [InfoQ: Java 27](https://www.infoq.com/news/2026/09/java27-released/) · [Kotlin 2.0 新特性](https://kotlinlang.org/docs/whatsnew20.html) · [Kotlin 2.4 新特性](https://kotlinlang.org/docs/whatsnew24.html) · [Kotlin 发布历史](https://kotlinlang.org/docs/releases.html)

---

## 1. 方法论：先估算、再测量

1. **先估算**：JVM 上"一个东西"的内存 ≈ 对象头 + 字段 + 对齐填充，再加上它引用的所有对象。第 2 章给出公式和本机实测值，写代码前就能算出 100 万个对象大约要多少内存。
2. **再测量**：
   - 对象大小 → JOL（`ClassLayout` / `GraphLayout`）；
   - 分配速率 → JMH `-prof gc` 的 `gc.alloc.rate.norm`（每次操作分配多少字节），或 `ThreadMXBean.getThreadAllocatedBytes`；
   - CPU 热点 → async-profiler / JFR；
   - 吞吐与延迟 → JMH（不要用 `System.nanoTime()` 包一个循环，JIT 预热、死代码消除、常量折叠都会让结果失真）。
3. **只优化热点**。对一个只会创建几十个实例的配置类做位压缩，是浪费时间；对一个装了 1000 万元素的 `List<Integer>` 改成 `int[]`，是数量级的收益（见第 3 章实测）。
4. **改完再测一次**，保留测试和断言。

工具用法见第 14 章。

---

