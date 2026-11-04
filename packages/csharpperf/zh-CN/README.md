# csharp性能

C# 性能笔记、小示例，以及 `csharpperf-lint`。

属于 [XPerf](../../../zh-CN/README.md) 的一部分。共享文档: [docs/README.md](../../../docs/zh-CN/README.md)。**语料库就绪**；cs-regex-hot=提示；cs-list-add-no-capacity–cs-console-hot **关闭**（启发式；升级需要 JSONL 证据以及政策决定）。指南 v0。

## 目录

- [英文指南 (v0)](../docs/zh-CN/csharp-performance-guide.md) — 来自 `docs/guide-src/`
- [`csharpperf-lint`](../csharpperf-lint/README.md) — cs-list-add-no-capacity–cs-regex-hot
- [语料库固定](../docs/zh-CN/corpus.md)

## 焦点

预先设置 `List` 容量，避免字符串呈二次方增长，避免在紧密循环中使用 `Console.Write*`。

## 运行 lint

```sh
cd packages/csharpperf/csharpperf-lint
cd packages/csharpperf/csharpperf-lint
dotnet build -c Release
dotnet build -c Release
dotnet run -c Release --no-build -- path/to/sources
dotnet run -c Release --no-build -- path/to/sources
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
csharpperf-lint/  checker + fixtures
csharpperf-lint/  checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh (both skip when `dotnet` is absent)
scripts/          smoke-lint.sh, self-lint.sh (both skip when `dotnet` is absent)
```}
