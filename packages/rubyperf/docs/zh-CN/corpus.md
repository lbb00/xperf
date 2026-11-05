# rubyperf 语料库目标

大型树木**不会**被转售，并且语料库不会随仓库一起分发：将其克隆到仓库之外的任何本地目录，并将该路径传递给代码检查器。

```sh
ruby packages/rubyperf/rubyperf-lint/rubyperf-lint.rb <corpus-dir>/<name> --format json --no-fail
```

检查器：`rubyperf-lint`。2026-10-22 的分类覆盖了 rb-string-plus-hot–rb-hash-merge-in-loop。`rb-hash-merge-in-loop` 于 2026-10-23 被移除。

## 固定目标

上游默认分支的浅克隆；提交未被记录。

| Tree | URL |
|------|-----|
| Rails（ActiveSupport + ActiveRecord）| https://github.com/rails/rails |
| jekyll | https://github.com/jekyll/jekyll |
| sidekiq | https://github.com/sidekiq/sidekiq |

## Lint 计数 — 之后 → r2 → r3（重新设计）

| 树 | 纤维绒（之后 → r2 → **r3**） |
|------|------------------------------|
| **rails** AS+AR | **4 → 1 → 2** (rb-hash-merge-in-loop) |
| **jekyll** | **0 → 0 → 0** |
| **sidekiq** | **5 → 0 → 2** (rb-hash-merge-在循环中) |

## G3 TP/FP 分诊（2026-10-22 亚洲/上海）

| 阶段 | n 样本 | 真阳性 | 假阳性+文档+跳过 | 语料库准备好？ |
|-------|----------|----|-------------|----------------|
| after/r1 | 9 | 0% | 33.3% | **no** |
| r2 | 1 | 0% | 0% | **no** (OK-idiom) |
| **r3** (rb-hash-merge-in-loop) | **4** | **75%** | **0%** | **是** |

r2→r3：将 rb-string-plus-hot–rb-puts-hot 降级 → **关闭**；添加 **rb-hash-merge-in-loop**（提示）。测量的 G4 证据：见 [evidence-policy.md](evidence-policy.md)。

## 2026-10-23 — 提示规则不在 2026-10-22 判决范围内

2026-10-22 的语料库准备判决不包括以下子弹头。它们仍然保持 **提示** 状态，尚未经过 G2/G3。

- `rb-regexp-new-hot`、`rb-json-hot` — 磁盘上的 JSONL；仍然是提示
