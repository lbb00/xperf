# arktsperf

HarmonyOS **ArkTS** 性能笔记、小示例，以及 `arktsperf-lint`（纯 Node，零 npm 依赖）。ArkTS 类似 TypeScript；检查器接受 `.ets`、`.ts` 和 `.js` 文件。

[XPerf](../../../zh-CN/README.md) 的一部分。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。**语料库就绪**（AGENT.md G3）。默认值：`at-includes-hot` 和 `at-json-hot` **启用**；`at-alloc-hot` 和 `at-console-hot` **关闭**。`at-object-delete` 在一个 Node 代理保持约 1× 后被移除。Guide v0 脚手架。

## 目录

- [英文指南 (v0)](../docs/zh-CN/arkts-performance-guide.md) — 来自 `docs/guide-src/`
- [`arktsperf-lint`](../arktsperf-lint/README.md) — 五条规则（见其表格获取默认值）
- [语料库固定](../docs/zh-CN/corpus.md)

## 焦点

嵌入式/类似小程序的约束：热分配、多态对象形状，以及 UI 或 worker 热路径上的同步桥/控制台通信。**at-console-hot**（循环中的 `console.*`）在 G3 之后默认 **关闭**（采样噪声）；可通过 `--severity at-console-hot=hint` 启用。没有设备或本地测试平台的声明仍为临时性质。**语料库就绪：是** — 参见 [docs/corpus.md](../docs/zh-CN/corpus.md)。

## 运行 lint

```sh
cd packages/arktsperf
cd packages/arktsperf
node arktsperf-lint/bin/arktsperf-lint.js path/to/sources
node arktsperf-lint/bin/arktsperf-lint.js path/to/sources
bash scripts/smoke-lint.sh
bash scripts/smoke-lint.sh
bash scripts/self-lint.sh
bash scripts/self-lint.sh
```}

仅在 **错误** 严重性发现时退出 `1`（提示默认退出 `0`，除非使用 `--strict-hints`）。

## 布局

```text
docs/guide-src/   chapter sources
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         per-rule Node-proxy evidence (*.md + *.jsonl)
evidence/         per-rule Node-proxy evidence (*.md + *.jsonl)
examples/         tiny ArkTS/TS demos
examples/         tiny ArkTS/TS demos
arktsperf-lint/   pure-JS checker + fixtures
arktsperf-lint/   pure-JS checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
scripts/          smoke-lint.sh, self-lint.sh
```}
