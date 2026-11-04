# 光束性能

> **范围说明:** **beamperf** 在一个 BEAM 工具包下涵盖 **Elixir 和 Erlang**。Lint 扫描 `.ex` / `.exs` / `.erl` 文件。优先使用 Elixir CLI；Erlang 模式在同一遍扫描中被识别。不同于 JVM 工具包。

Elixir + Erlang (BEAM) 性能笔记、小示例，以及 `beamperf-lint`。

属于 [XPerf](../../../zh-CN/README.md) 的一部分。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。**语料库就绪**。`be-list-concat-reduce`、`be-map-merge-hot` 和 `be-enum-map-filter-chain` **提示**；`be-io-puts-hot` **关闭**。删除了一条规则（墓碑，从未得到过 slug）。没有 G4。指南 v0。

## 目录

- [英文指南 (v0)](../docs/zh-CN/beam-performance-guide.md) — 来自 `docs/guide-src/`
- [`beamperf-lint`](../beamperf-lint/README.md) — 四条规则（参见其表格获取默认值）
- [语料库固定](../docs/zh-CN/corpus.md)

## 焦点

避免在循环中使用 `list ++` 和字符串/`<>` 的增长（优先使用 cons + reverse 或 iolist），在频繁执行的循环中不要使用 `IO.puts` / `io:format`。

## 运行 lint

```sh
elixir packages/beamperf/beamperf-lint/beamperf_lint.exs path/to/sources
elixir packages/beamperf/beamperf-lint/beamperf_lint.exs path/to/sources
bash packages/beamperf/scripts/smoke-lint.sh
bash packages/beamperf/scripts/smoke-lint.sh
bash packages/beamperf/scripts/self-lint.sh
bash packages/beamperf/scripts/self-lint.sh
```}

仅在 **错误** 严重性发现时退出 `1`（提示默认退出 `0`，除非使用 `--strict-hints`）。

## 布局

```text
docs/guide-src/   chapter sources
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         per-rule measured evidence (*.md + *.jsonl) and _removed/ tombstones
evidence/         per-rule measured evidence (*.md + *.jsonl) and _removed/ tombstones
examples/         tiny demos
examples/         tiny demos
beamperf-lint/    checker + fixtures
beamperf-lint/    checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
scripts/          smoke-lint.sh, self-lint.sh
```}
