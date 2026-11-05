# pyperf

Python 性能笔记和 `pyperf-lint`（不是 PyPI 微基准测试工具）。

[XPerf](../../../zh-CN/README.md) 的一部分。**语料库就绪**（G3 2026-10-22）。默认设置：pp-str-plus-hot/pp-print-hot **关闭**，pp-list-plus-rebind **提示**。删除了一条规则（墓碑，从未获得标识符）。

## 目录

- [英文指南](../docs/zh-CN/python-performance-guide.md)
- [`pyperf-lint`](../pyperf-lint/README.md) — pp-str-plus-hot / pp-list-plus-rebind / pp-print-hot
- [语料库固定](../docs/zh-CN/corpus.md)

## 关注点

在性能关键的循环中，优先使用 `''.join(...)` 而不是 `s +=`，优先使用 `append` 而不是 `xs = xs + [...]`；避免在紧密循环中使用 `print`。

## 运行 lint

```sh
export PYTHONPATH=packages/pyperf/pyperf-lint
python3 -m pyperf_lint path/to/sources
bash packages/pyperf/scripts/smoke-lint.sh
bash packages/pyperf/scripts/self-lint.sh
```

## 布局

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         pp-str-plus-hot, pp-list-plus-rebind, pp-print-hot measured (not escalated); PP004 tombstone
examples/         tiny demos + evidence bench
pyperf-lint/      checker (pyperf_lint package) + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
