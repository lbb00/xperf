# cppperf

> **范围说明：** **cppperf** 专用于 **C++17**。同类 [cperf](../../cperf/) 依旧支持 **C11/C17**（+ 轻量级 C++）。请勿合并这两个工具包。

C++17 性能笔记、小例子，以及 `cppperf-lint`。

[XPerf](../../../zh-CN/README.md) 的一部分。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。针对 2026-10-22 规则集 **语料库就绪**。regex、endl、clock、ifstream、const-by-value 和 vector-bool 提示带有 JSONL。已移除字符串追加和字符串流。删除了三个较旧的规则（tombstone, 从未得到 slug）。Guide v0 骨架。

## 目录

- [英文指南 (v0)](../docs/zh-CN/cpp-performance-guide.md) — 来自 `docs/guide-src/`
- [`cppperf-lint`](../cppperf-lint/README.md) — 字符串追加、正则表达式、endl 和时钟提示；移除了三个规则（tombstone，从未获得 slug）
- [语料库固定](../docs/zh-CN/corpus.md)

## 焦点

在进行热 `push_back` 之前预留空间，避免字符串二次增长，在紧密循环中不要使用 `iostream`（建议在外部使用缓冲/`fmt`）。

## 运行 lint

```sh
cd packages/cppperf/cppperf-lint && make
cd packages/cppperf/cppperf-lint && make
./cppperf-lint path/to/sources
./cppperf-lint path/to/sources
bash ../scripts/smoke-lint.sh
bash ../scripts/smoke-lint.sh
bash ../scripts/self-lint.sh
bash ../scripts/self-lint.sh
```}

仅在 **错误** 严重级别的发现时退出 `1`（提示默认退出 `0`，除非使用 `--strict-hints`）。

## 布局

```text
docs/guide-src/   chapter sources
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         measured JSONL; _removed/ tombstones including cx-string-append-unreserved
evidence/         measured JSONL; _removed/ tombstones including cx-string-append-unreserved
examples/         tiny demos
examples/         tiny demos
cppperf-lint/    checker + fixtures
cppperf-lint/    checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
scripts/          smoke-lint.sh, self-lint.sh
```}
