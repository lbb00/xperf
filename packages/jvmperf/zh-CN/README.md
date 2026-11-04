# jvm性能

JVM（Java / Kotlin）性能笔记、可运行示例、JMH/JOL 基准，以及用 **Java** 编写的 `jvmperf-lint`。

属于 [XPerf](../../../zh-CN/README.md)。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。**语料库就绪**。小型证据 JSONL 位于 `evidence/` 下。

## 目录

- [英文指南](../docs/en/performance-guide.md) — 来自 `docs/guide-src/en/`
- [`jvmperf-lint`](../jvmperf-lint/) — **Java** 检查器（Gradle，tree-sitter）
- [语料库固定](../docs/zh-CN/corpus.md)
- [证据指针](../evidence/zh-CN/README.md) · [证据政策](../docs/zh-CN/evidence-policy.md)
- HotSpot 关联：`scripts/run-static-vs-hotspot.sh`

## 焦点

分配/装箱，布局（SoA，原始映射），热路径字符串和 I/O，JIT/伪共享/虚拟线程，Kotlin 序列和内联。没有本地基准或引用的说法保持暂定；语料库计数是 lint 内部使用。

## 要求

- **JDK 21** 用于构建和测试 `jvmperf-lint`（CI：Temurin 21）。将 `JAVA_HOME` 固定为 21 — 仅使用主机 JDK 25 可能会导致 Gradle 报错，出现不明确的 `25.0.x` 信息。该项目使用 Java **21** 工具链 + Foojay 解析器。
- **JDK 25** 可选，用于 JMH/JOL 示例和基准测试（运行这些脚本时使用单独的 `JAVA_HOME`）
- Kotlin 2.4.x 用于 Kotlin 示例（`scripts/check_kotlin.sh`）
- `lib/` 中的可选 jar 文件 — **不在 git 中**；使用 `bash scripts/fetch-lib.sh` 拉取（参考 `lib/README.md`）。默认 `JVMPERF_LIB_DIR=$ROOT/lib`

## 运行 lint

```sh
cd packages/jvmperf/jvmperf-lint
cd packages/jvmperf/jvmperf-lint
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
./gradlew test jar
./gradlew test jar
bin/jvmperf-lint ../examples --no-fail
bin/jvmperf-lint ../examples --no-fail
bin/jvmperf-lint --list-rules
bin/jvmperf-lint --list-rules
```}

当存在发现时退出代码为 `1`（除非使用 `--no-fail`）。在使用/输入输出错误时退出代码为 `2`。

**严重性说明:** 除非使用 `--no-fail`，否则进程退出仍会将任何发现视为失败。每条规则的默认严重性（`error`、`hint` 或 `off`）遵循 `docs/evidence-policy.md`；标记为 `off` 的规则不会运行，除非使用 `--enable` 选择（此时只运行所列规则）。完整的 `--preset` 配置可能稍后推出。

自检：`./gradlew test`（夹具 + 单元）。使用 `--no-fail` 的内部示例作为审查提示。

## 长凳与支票

```sh
# From packages/jvmperf: rebuild guides from docs/guide-src (code samples are inlined in the chapter files)
# From packages/jvmperf: rebuild guides from docs/guide-src (code samples are inlined in the chapter files)
bash ../../scripts/build-guides.sh jvmperf
bash ../../scripts/build-guides.sh jvmperf
scripts/check_java.sh
scripts/check_java.sh
scripts/check_kotlin.sh
scripts/check_kotlin.sh
# JMH / JOL / Kotlin alloc (writes JSONL under research/bench-results):
# JMH / JOL / Kotlin alloc (writes JSONL under research/bench-results):
# scripts/run_jmh.sh …
# scripts/run_jmh.sh …
# scripts/run_jol_maps.sh
# scripts/run_jol_maps.sh
# scripts/run_kotlin_alloc.sh
# scripts/run_kotlin_alloc.sh
```}

## 布局

```text
docs/guide-src/     chapter sources (en/, zh-CN/)
docs/guide-src/     chapter sources (en/, zh-CN/)
docs/               assembled guides + corpus.md
docs/               assembled guides + corpus.md
examples/           java + kotlin (+ android fixtures)
examples/           java + kotlin (+ android fixtures)
jvmperf-lint/       Java checker (Gradle) + fixtures
jvmperf-lint/       Java checker (Gradle) + fixtures
jmh-benches/        JMH sources
jmh-benches/        JMH sources
lib/                optional jars (gitignored; fetch-lib.sh)
lib/                optional jars (gitignored; fetch-lib.sh)
research/           small in-tree Jol/EA probe sources (no *.log dumps)
research/           small in-tree Jol/EA probe sources (no *.log dumps)
scripts/            run_*, check_*, env.sh (build_guide is superseded by the repo-level scripts/build-guides.sh)
scripts/            run_*, check_*, env.sh (build_guide is superseded by the repo-level scripts/build-guides.sh)
evidence/           pointers to research JSONL (not full dumps)
evidence/           pointers to research JSONL (not full dumps)
```}
