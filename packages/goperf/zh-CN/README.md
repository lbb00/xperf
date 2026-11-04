# goperf

Go 性能笔记、小示例，以及用 **Go** 编写的 `goperf-lint`。

[XPerf](../../../zh-CN/README.md) 的一部分。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。**语料库就绪**（G3 2026-10-22）。默认配置：gp-make-hot–gp-fmt-hot **关闭**，gp-append-nil-slice/gp-defer-hot **提示**。没有虚构的 JSONL。

## 目录

- [英文指南 (v0)](../docs/zh-CN/go-performance-guide.md) — 来自 `docs/guide-src/`
- [`goperf-lint`](../goperf-lint/README.md) — gp-make-hot–gp-defer-hot
- [语料库固定](../docs/zh-CN/corpus.md)

## 焦点

带有大小提示的空切片增长（`make([]T, 0, n)`），循环中的 `defer` 堆积。旧的 make/string/fmt 循环启发式在 G3 OK-idiom 降级后仍为可选。

## 运行 lint

```sh
cd packages/goperf/goperf-lint
cd packages/goperf/goperf-lint
go build -o goperf-lint ./cmd/goperf-lint
go build -o goperf-lint ./cmd/goperf-lint
./goperf-lint path/to/sources
./goperf-lint path/to/sources
./goperf-lint path/to/sources --severity gp-append-nil-slice=error
./goperf-lint path/to/sources --severity gp-append-nil-slice=error
bash ../scripts/smoke-lint.sh
bash ../scripts/smoke-lint.sh
bash ../scripts/self-lint.sh
bash ../scripts/self-lint.sh
```}

仅当存在**错误**严重性的发现时才退出 `1`（提示信息会打印，但除非使用 `--strict-hints`，否则退出码为 `0`）。

## 布局

```text
docs/guide-src/   chapter sources
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         per-rule claims + measured JSONL
evidence/         per-rule claims + measured JSONL
examples/         tiny Go demos
examples/         tiny Go demos
goperf-lint/      Go checker + fixtures
goperf-lint/      Go checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
scripts/          smoke-lint.sh, self-lint.sh
```}
