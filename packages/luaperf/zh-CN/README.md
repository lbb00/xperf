# luaperf

> **范围说明:** **luaperf** 针对 **Lua 5.1–5.4** / LuaJIT 的常见模式。启发式检测；在升级前先进行测量。

Lua 性能注意事项、小示例和 `luaperf-lint`。

[XPerf](../../../zh-CN/README.md) 的一部分。共享文档: [docs/README.md](../../../docs/zh-CN/README.md)。启发式 lint (**语料库就绪: 是**; **lu-string-concat-hot=错误** 与 G4; lu-table-insert-hot=关; lu-print-hot=提示 与 G4)。指南 v0。

## 目录

- [英文指南 (v0)](../docs/zh-CN/lua-performance-guide.md) — 来自 `docs/guide-src/`
- [`luaperf-lint`](../luaperf-lint/README.md) — lu-table-insert-hot–lu-print-hot
- [语料库固定](../docs/zh-CN/corpus.md)

## 焦点

在已知长度时预先设置表大小，在循环中尽量使用 table.concat 而不是 `..`，避免在高频循环中使用 `print`。

## 运行 lint

```sh
lua packages/luaperf/luaperf-lint/luaperf-lint.lua path/to/sources
bash packages/luaperf/scripts/smoke-lint.sh
bash packages/luaperf/scripts/self-lint.sh
```

仅在 **错误** 严重级别的发现时退出 `1`（提示默认退出 `0`，除非使用 `--strict-hints`）。

## 布局

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         lu-string-concat-hot measured (error); lu-print-hot measured (hint); lu-table-insert-hot measured (off)
examples/         tiny demos
luaperf-lint/      checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
