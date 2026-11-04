# pyperf 语料库目标

大型树木**不是**经过供应的，并且语料库不会随仓库一起分发：将其克隆到仓库之外的任意本地目录，并将该路径传递给代码检查器。

这个包是 **XPerf 的 Python 嗅探工具包**，不是 PyPI 上的 `pyperf` 基准测试运行器。

## 固定目标

| 树 | URL | 提交 | 备注 |
|------|-----|--------|-------|
| django | https://github.com/django/django | `3d3d943b7442f1f5278ed876331a06047fa96ea8` | 浅层 |
| flask | https://github.com/pallets/flask | `d086db856be187255b8ec61ef409357393020f32` | 浅层 |
| requests | https://github.com/psf/requests | `611c6162cbc4ac2020a2f91c7cfa4f3abf9bbb60` | 浅拷贝; 默认下 0 |

## G3 摘要（2026-10-22 亚洲/上海）——重新设计

| 树 | r2 | r3（默认值） | 语料库就绪？ |
|------|----|---------------|---------------|
| django | 27 | **28** | PP004 |
| flask | 0 | **1** | CLI OK-惯用语 |
| requests | 0 | **0** | clean |

**判决：语料库就绪 `是`。** 样本 n=29：TP 51.7% / OK-成语 48.3% / FP+DOC+跳过 0%。默认值：pp-str-plus-hot/pp-print-hot **关闭**；pp-list-plus-rebind **提示**。PP004 已移除（抖动）。测量的 JSONL 填充存在，但不会更改默认值（参见 [evidence-policy.md](evidence-policy.md)）。

### 重新设计笔记

- PP004：函数内部的临时 `re.METHOD(literal)`
- 跳过：`scripts/`，`management/commands/`

不要将语料库来源提交到 `packages/pyperf`。

## 2026-10-23 — 提示2026-10-22裁决之外的规则

2026-10-22 的语料库准备判决不包括以下子弹头。它们仍然保持 **提示** 状态，尚未经过 G2/G3。

- `pp-json-hot`、`pp-deepcopy-hot` — 磁盘上的 JSONL；仍然是提示

`pp-regex-compile-in-loop` 和 `pp-datetime-format-in-loop` 已被移除。请参见 `evidence/_removed/`。它们不是该裁决的一部分。
