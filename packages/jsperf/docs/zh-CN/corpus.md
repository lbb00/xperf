# jsperf 语料库目标

工作候选列表：引擎 + 热路径库，而不是随机的 npm 包。树不会随仓库一起提供；请将它们克隆到仓库外的任意本地目录（quickjs JS 树与 C 套件共享）。

```sh
node jsperf-lint/bin/jsperf-lint.js <path-to-clone> --format json --no-fail
```

检查器：**jsperf-lint**。

## 固定目标

| 树 | URL | 提交 | 范围 |
|------|-----|--------|-------|
| 节点 | https://github.com/nodejs/node | `796a83a7` | 浅层; `lib/**/*.js` |
| Preact | https://github.com/preactjs/preact | `74df25e` | `src/` |
| quickjs | 与 C 套件共享 — 参见 [cperf 语料库](../../../cperf/docs/zh-CN/corpus.md) | `7d1c13c` | `*.js`（跳过 `gen-*`） |
| TypeScript | https://github.com/microsoft/TypeScript | `538671d3c` | `packages/typescript/src` |

## 是否 corpus-ready？

**是的** — 重新设计后的 G3 2026-10-22（亚洲/上海）。默认剩余 **31× jp-string-plus-in-loop**（22 个 TP / 9 个 OK-idiom）。FP+DOC+SKIP **0%**。jp-delete-shape→`off`（之前是 100% OK-idiom）。分类注释未随版本发布（重新设计后）。

jp-delete-array-hole 保持 **错误**（G4）。当天 jp-string-plus-in-loop 和 jp-map-filter-chain 默认 **提示**（string-plus 于 2026-10-23 被移除；见下文）。jp-alloc-hot/jp-console-hot/jp-delete-shape 默认 **关闭**。

## 克隆 — g3e（2026-10-22 重新设计）

| 树 | 大小 | 发现 g3c → g3e |
|------|------|--------------------|
| **节点 `lib/`** | ~7M `lib/` | **38 jp-delete-shape → 29 jp-string-plus-in-loop** |
| **Preact `src/`** | 3.3M | **0 → 0** |
| **quickjs JS** | (shared) | **0 → 0** |
| **TypeScript** | 源码 1.9M | **0 → 2** 循环中的 jp-string-plus |

G3 重新设计：jp-delete-shape→关闭；jp-string-plus-in-loop string-append-in-loop；jp-map-filter-chain map/filter 链；冷格式化器 + gen-file 跳过。

目录跳过：`node_modules`、`.git`、`dist`、`coverage`、`tests`、`test`、`benchmarks`、`demo`、`fixtures`。
文件跳过：`gen-*`、`*generate*`、`diagnosticFormatter.ts`。
jp-string-plus-in-loop 和 jp-map-filter-chain 也跳过 inspect/debugger/test_runner/reporter/bench_runner/assert/myers_diff/cli_table 路径。

## 克隆订单

1. **已完成:** 节点 `lib/` + Preact + quickjs JS + TypeScript `packages/typescript/src`
2. 后续: 较旧的 TS 标签，包含大型 `src/compiler`，Solid / lodash-es

## 小程序 / 嵌入焦点

保持指南建议可用于 **嵌入式 JS 和 小程序类** 运行时 (QuickJS)。

## 库存

```text
<corpus-dir>/
  node/
  preact/
  TypeScript/
  quickjs/   # shared with the C kit
```

## 2026-10-23 — 提示规则不在 2026-10-22 判决范围内

2026-10-22 的语料库准备判决不包括以下子弹头。它们仍然保持 **提示** 状态，尚未经过 G2/G3。

- `jp-regex-ctor-hot`，`jp-json-hot` — 磁盘上的 JSONL；仍然提示。绑定到循环的模式或文本未被报告。
- `jp-dom-query-hot`，`jp-intl-datetimeformat-hot` — 磁盘上的 JSONL；仍然提示。绑定到循环的选择器、语言环境或选项值未被报告。
- `jp-readfile-sync-hot`，`jp-clock-hot` — 磁盘上的 JSONL；仍然提示。`for` 可迭代对象不是循环体。使用 `await` 的循环不是 clock 基准。
- `jp-map-filter-chain` — 磁盘上的 JSONL；仍然提示。长数组大约提高了 4.6×–9.8×；三行的 filter+map 提高了 1.28×。
- `jp-string-plus-in-loop` — 在同一天移除。上面 2026-10-22 的残留计数是历史数据。匹配器不再运行，这些树也没有为本注释重新进行 lint。
