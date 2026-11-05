# swiftperf

Swift 性能笔记、小示例，以及 `swiftperf-lint`（Swift Package）。

属于 [XPerf](../../../zh-CN/README.md)。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。针对 2026-10-22 规则（AGENT.md G3）lint **corpus-ready**。默认：sp-array-no-reserve **hint**；sp-print-hot **off**。强制解包、字符串 `+=` 与 `map`/`joined` 在本地 `swiftc -O` 跑后已移除。三条较晚 hint（`sp-dateformatter-hot`、`sp-json-decode-hot`、`sp-regex-hot`）在该裁决之外。指南 v0 脚手架；无 Swift SDK 时有 text-lint 对等。

> **工具链：** 你运行的机器上可能没有 `swift`。源码 + `Package.swift` 仍随仓库提供；有 Swift 5.9+ 时再构建。夹具与文档在不编译时也完整。

## 目录

- [英文指南（v0）](../docs/zh-CN/swift-performance-guide.md) — 来自 `docs/guide-src/`
- [`swiftperf-lint`](../swiftperf-lint/README.md) — 从 sp-array-no-reserve 到热调用 hint（sp-array-no-reserve 与 2026-10-23 热调用规则为 hint；print 为 off）
- [语料固定目标](../docs/zh-CN/corpus.md)

## 关注点

热循环里的强制解包、字符串拼接增长，以及热路径 `print`。没有本地基准的主张保持暂定。

## 运行 lint

```sh
cd packages/swiftperf/swiftperf-lint
swift build -c release
"$(swift build -c release --show-bin-path)/swiftperf-lint" path/to/sources
bash ../scripts/smoke-lint.sh
```

无 Swift 时：`scripts/smoke-lint.sh` 经 [`scripts/text-lint.cjs`](../scripts/text-lint.cjs) 跑 G0（与 SPM 源启发式对等）。语料 G2/G3 用同一回退 — 见 [docs/corpus.md](../docs/zh-CN/corpus.md)。**corpus-ready: 是**（text-lint 对等；有 Swift 工具链时再用 SPM 复核）。

## 布局

```text
docs/guide-src/   章节源
docs/             组装后的指南 + corpus.md + evidence-policy.md
evidence/         阻塞 stub（有 Swift 工具链前无 JSONL）
examples/         小 Swift 演示
swiftperf-lint/   Package.swift + Sources + 夹具
scripts/          smoke-lint.sh, self-lint.sh, text-lint.cjs（无 swift 时的回退）
```
