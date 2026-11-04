# kotlinperf

> **范围说明：** **kotlinperf** 是 **以 Kotlin 为先**（协程 / 集合 / 热 I/O 异味）。同类项目 [jvmperf](../../jvmperf/) 仍然是经测量的 **JVM/Java(+Kotlin)** 工具包，并附有 JMH/JOL 证据 — **不要在这里重复 JMH 证据**；可将测量声明交叉链接到 jvmperf。本工具包的规则是启发式的，默认 **关闭**。

Kotlin 性能笔记、小示例，以及 `kotlinperf-lint`。

[XPerf](../../../zh-CN/README.md) 的一部分。共享文档: [docs/README.md](../../../docs/zh-CN/README.md)。**语料库就绪**。kt-list-add-hot–kt-println-hot **关闭**。移除了一条规则（墓碑，从未获得 slug）。指南 v0。

## 目录

- [英文指南 (v0)](../docs/zh-CN/kotlin-performance-guide.md) — 来自 `docs/guide-src/`
- [`kotlinperf-lint`](../kotlinperf-lint/README.md) — kt-list-add-hot / kt-string-plus-hot / kt-println-hot
- [语料库固定](../docs/zh-CN/corpus.md)

## 焦点

避免在热点循环中重复分配列表 / 字符串 `+=` / `println`；更倾向于使用构建器，并参考经过测量的 JVM 性能指南来进行 JVM 范围的优化。

## 运行 lint

```sh
cd packages/kotlinperf/kotlinperf-lint && bash build.sh
cd packages/kotlinperf/kotlinperf-lint && bash build.sh
./kotlinperf-lint path/to/sources
./kotlinperf-lint path/to/sources
bash ../scripts/smoke-lint.sh
bash ../scripts/smoke-lint.sh
bash ../scripts/self-lint.sh
bash ../scripts/self-lint.sh
```}

仅在 **错误** 严重性发现时退出 `1`（提示默认退出 `0`，除非使用 `--strict-hints`）。

## 布局

```text
docs/guide-src/   chapter sources
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         pending stubs until benches land
evidence/         pending stubs until benches land
examples/         tiny demos
examples/         tiny demos
kotlinperf-lint/  checker + fixtures
kotlinperf-lint/  checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
scripts/          smoke-lint.sh, self-lint.sh
```}
