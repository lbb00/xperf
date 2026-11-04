# rubyperf

Ruby 性能笔记、小示例，以及 `rubyperf-lint`。

属于 [XPerf](../../../zh-CN/README.md)。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。lint **corpus-ready**（启发式）。默认：rb-string-plus-hot、rb-array-plus-rebind、rb-puts-hot **off**；regexp / JSON / file-read **hint**。`rb-hash-merge-in-loop` 已移除。指南 v0。

## 目录

- [英文指南（v0）](../docs/zh-CN/ruby-performance-guide.md) — 来自 `docs/guide-src/`
- [`rubyperf-lint`](../rubyperf-lint/README.md) — rb-string-plus-hot–rb-file-read-hot
- [语料固定目标](../docs/zh-CN/corpus.md)

## 关注点

优先 `<<` 而非字符串 `+=`，避免循环里 Array `+` 重绑定，门控热路径 `puts`/`print`。

## 运行 lint

```sh
cd packages/rubyperf
cd packages/rubyperf
ruby rubyperf-lint/rubyperf-lint.rb path/to/sources
ruby rubyperf-lint/rubyperf-lint.rb path/to/sources
bash scripts/smoke-lint.sh
bash scripts/smoke-lint.sh
bash scripts/self-lint.sh
bash scripts/self-lint.sh
```

仅 **error** 级发现时退出 `1`（hint 退出 `0`，除非 `--strict-hints`）。

## 布局

```text
docs/guide-src/   章节源
docs/guide-src/   章节源
docs/             组装后的指南 + corpus.md + evidence-policy.md
docs/             组装后的指南 + corpus.md + evidence-policy.md
evidence/         每规则主张 + 实测 JSONL（全部四条规则）
evidence/         每规则主张 + 实测 JSONL（全部四条规则）
examples/         小演示
examples/         小演示
rubyperf-lint/    检查器 + 夹具
rubyperf-lint/    检查器 + 夹具
scripts/          smoke-lint.sh, self-lint.sh
scripts/          smoke-lint.sh, self-lint.sh
```
