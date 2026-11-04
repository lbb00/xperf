# dartperf

> **范围说明:** **dartperf** 针对 **Dart**（Flutter/VM）。启发式 lint；在升级前使用 `benchmark_harness` 测量。

Dart 性能笔记、小示例，以及 `dartperf-lint`。

部分 [XPerf](../../../zh-CN/README.md)。共享文档: [docs/README.md](../../../docs/zh-CN/README.md)。**语料库准备**。dt-list-add-empty–dt-print-hot **关闭**；**dt-growable-add-empty** 提示。指南 v0。

## 目录

- [英文指南 (v0)](../docs/zh-CN/dart-performance-guide.md) — 来自 `docs/guide-src/`
- [`dartperf-lint`](../dartperf-lint/README.md) — dt-list-add-empty–dt-growable-add-empty
- [语料库固定](../docs/zh-CN/corpus.md)

## 焦点

优先使用固定长度/容量感知的列表，避免在循环中使用字符串 `+`（使用 `StringBuffer`），在热点循环中不要使用 `print`。

## 运行 lint

```sh
cd packages/dartperf/dartperf-lint && dart pub get
cd packages/dartperf/dartperf-lint && dart pub get
dart run bin/dartperf_lint.dart path/to/sources
dart run bin/dartperf_lint.dart path/to/sources
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
dartperf-lint/  checker + fixtures
dartperf-lint/  checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
scripts/          smoke-lint.sh, self-lint.sh
```}
