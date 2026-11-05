# phpperf

PHP 性能笔记、小示例，以及 `phpperf-lint`。

属于 [XPerf](../../../zh-CN/README.md)。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。启发式 lint（**corpus-ready: 是**；**ph-array-merge-rebind=error** 带 G4；**ph-string-dot-hot=off**；ph-echo-hot=hint）。指南 v0。

## 目录

- [英文指南（v0）](../docs/zh-CN/php-performance-guide.md) — 来自 `docs/guide-src/`
- [`phpperf-lint`](../phpperf-lint/README.md) — ph-string-dot-hot–ph-echo-hot
- [语料固定目标](../docs/zh-CN/corpus.md)

## 关注点

避免平方级字符串增长（`.=`），优先 push 而非 `array_merge` 重绑定，门控热路径 `echo`/`print`。

## 运行 lint

```sh
cd packages/phpperf
php phpperf-lint/phpperf-lint.php path/to/sources
bash scripts/smoke-lint.sh
bash scripts/self-lint.sh
```

仅 **error** 级发现时退出 `1`（hint 退出 `0`，除非 `--strict-hints`）。

## 布局

```text
docs/guide-src/   章节源
docs/             组装后的指南 + corpus.md + evidence-policy.md
evidence/         ph-array-merge-rebind 已测（error）；ph-string-dot-hot 已测（off）；ph-echo-hot 已测（hint）
examples/         小演示
phpperf-lint/     检查器 + 夹具
scripts/          smoke-lint.sh, self-lint.sh
```
