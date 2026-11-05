# nimperf

Nim 性能注意事项和同语言的 `nimperf-lint`。

[XPerf](../../../zh-CN/README.md) 的一部分。**语料准备就绪**（G3 2026-10-22）。默认设置：nm-seq-add-hot 和 nm-echo-hot **关闭**；nm-seq-no-capacity **提示**。`nm-string-amp-in-loop` 已移除。需要 `nim`（choosenim）。

## 目录

- [英文指南 (v0)](../docs/zh-CN/nim-performance-guide.md) — 由 `docs/guide-src/` 生成
- [`nimperf-lint`](../nimperf-lint/README.md) — 规则和严重性
- [规则ID](../docs/zh-CN/rule-ids.md) · [证据政策](../docs/zh-CN/evidence-policy.md) · [语料库固定](../docs/zh-CN/corpus.md)

## 运行 lint

```sh
packages/nimperf/nimperf-lint/nimperf-lint path/to/sources
bash packages/nimperf/scripts/smoke-lint.sh
bash packages/nimperf/scripts/self-lint.sh
```

## 布局

| 路径 | 内容 |
|------|----------|
| `docs/` | 指南（`guide-src/` 是源文件）、语料库固定、证据政策、规则 ID |
| `evidence/` | 每条规则的证据笔记（全部待定；参见 [evidence/README.md](../evidence/zh-CN/README.md)） |
| `examples/` | `m01_presize.nim`，`p01_join.nim` |
| `nimperf-lint/` | linter 源代码、测试夹具、README |
| `scripts/` | `smoke-lint.sh`，`self-lint.sh` |
