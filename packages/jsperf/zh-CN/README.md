# jsperf

面向 V8/Node 和嵌入环境（QuickJS / 类小程序）的 JavaScript/TypeScript 性能笔记：隐藏类、元素类型、垃圾回收压力、类型化数组、异步批处理，以及避免多态热路径。

[XPerf](../../../zh-CN/README.md) 的一部分。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。该 lint 是 **纯 JS**（Node ≥18，无 npm 依赖）并带有严重性预设。Guide v0 包括 **§4 V8 优化**（单机微基准，Node 22.22.3）和 **§5 启动/工具链**（Marvin 系列方法）。

## 目录

- [英文指南 (v0)](../docs/zh-CN/js-performance-guide.md) — 来自 `docs/guide-src/`（包括 `04_v8_optimizations`，`05_startup_and_tooling`）
- [`jsperf-lint`](../jsperf-lint/README.md) — jp-* 规则
- [证据政策](../docs/zh-CN/evidence-policy.md) · [规则 ID](../docs/zh-CN/rule-ids.md)
- [语料库固定项](../docs/zh-CN/corpus.md)
- V8 测试：`examples/bench/` · `scripts/run-v8-benches.sh`

## 运行 lint

```sh
node jsperf-lint/bin/jsperf-lint.js path/to/sources --preset app   # default
node jsperf-lint/bin/jsperf-lint.js path/to/sources --preset app   # default
node jsperf-lint/bin/jsperf-lint.js path/to/sources --preset all
node jsperf-lint/bin/jsperf-lint.js path/to/sources --preset all
node jsperf-lint/bin/jsperf-lint.js path/to/sources --scope all|loop   # default all
node jsperf-lint/bin/jsperf-lint.js path/to/sources --scope all|loop   # default all
node jsperf-lint/bin/jsperf-lint.js path/to/sources --severity jp-alloc-hot=error
node jsperf-lint/bin/jsperf-lint.js path/to/sources --severity jp-alloc-hot=error
npm run self-lint   # dogfood own sources; must exit 0
npm run self-lint   # dogfood own sources; must exit 0
npm test            # fixtures + preset smoke
npm test            # fixtures + preset smoke
```}

默认 **应用**：jp-delete-array-hole = 错误；jp-map-filter-chain、jp-regex-ctor-hot、jp-json-hot、jp-dom-query-hot、jp-intl-datetimeformat-hot、jp-readfile-sync-hot 和 jp-clock-hot = 提示；jp-alloc-hot、jp-console-hot 和 jp-delete-shape = 关闭。默认 **`--scope all`** 也会报告循环外的这些异味（如需仅匹配循环内，请选择 `--scope loop`）。jp-string-plus-in-loop 已移除。仅对错误等级的发现退出 `1`。

证据 JSONL 门：[`evidence/`](../evidence/)（jp-alloc-hot、jp-console-hot、jp-delete-shape、jp-delete-array-hole）。政策：[`docs/evidence-policy.md`](../docs/zh-CN/evidence-policy.md)。重新生成：`bash scripts/regen-evidence.sh`。

## 布局

| 路径 | 内容 |
|------|----------|
| `docs/` | 指南 (`guide-src/` 是源文件), 语料库固定, 证据政策, 规则 ID |
| `evidence/` | 每条规则的证据笔记和 JSONL |
| `examples/` | 说明性片段; `examples/bench/` 包含 V8 微基准 |
| `jsperf-lint/` | linter 源码, 测试夹具, README |
| `scripts/` | 烟雾测试, 基准测试和证据运行器 |

## 示例 / 长凳

```sh
node examples/m01_hidden_class.js
node examples/m01_hidden_class.js
node examples/p01_typed_array.js
node examples/p01_typed_array.js
# Prefer Node 22+ for §4 numbers:
# Prefer Node 22+ for §4 numbers:
NODE_BIN=$(command -v node) bash scripts/run-v8-benches.sh
NODE_BIN=$(command -v node) bash scripts/run-v8-benches.sh
NODE_BIN=$(command -v node) bash scripts/jit-check.sh          # --trace-deopt sample
NODE_BIN=$(command -v node) bash scripts/jit-check.sh          # --trace-deopt sample
NODE_BIN=$(command -v node) bash scripts/run-static-vs-v8.sh   # smell vs wall-clock
NODE_BIN=$(command -v node) bash scripts/run-static-vs-v8.sh   # smell vs wall-clock
```}
