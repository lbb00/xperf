# XPerf 文档

**XPerf** 伞形（多工具包系列）的共享文档。各语言的指南和 Lint 文档存放在各自的包下。

GitHub Pages 会渲染此目录及每个工具包的指南。使用 `bash scripts/build-pages.sh serve` 进行预览。参见 [release.md](release.md)。

## 共享文档（本目录）

| 文档 | 目的 |
|-----|---------|
| [branding.md](branding.md) | 显示名称 **XPerf** 与路径 `xperf` |
| [doc-style.md](doc-style.md) | 由 `scripts/doc-check.sh` 执行的 Markdown 规范 |
| [release.md](release.md) | 我们在 `v*` 标签上发布的内容 |
| [overview.md](overview.md) | XPerf 是什么：工具架构、共享循环、证据规则 |
| [playbook.md](playbook.md) | 操作循环：库存 → 证据 → 语料库 → 反向优化 → 内部测试 → 文档 |
| [kits.md](kits.md) | 检查入口点、默认值、语料库准备笔记（仅限短标签） |
| [quickstart.md](quickstart.md) | 每种语言的构建/运行命令 |
| [smell-catalog.md](smell-catalog.md) | 跨语言气味指数（ID为每套工具的标识符） |
| [rule-regression.md](rule-regression.md) | 正/负夹具 + 证据覆盖；诚实的缺口 |
| [rule-id-map.md](rule-id-map.md) | 历史数字 → 标识符映射（命令行接口不接受数字） |
| [roadmap-next.md](roadmap-next.md) | 以相同方法进行下一项工作 |
| [static-check-sources.md](static-check-sources.md) | 论坛、博客和 GitHub 上 linter 可以检测到的形状的来源 |

## 各 package 入口

| 工具包 | 指南 | 语料/证据政策 | Lint 文档 |
|-----|-------|--------------------------|-----------|
| **zperf** | [zig-performance-guide.md](../../packages/zperf/docs/zh-CN/zig-performance-guide.md) | [evidence-policy.md](../../packages/zperf/docs/zh-CN/evidence-policy.md) · `packages/zperf/evidence/` | [zperf-lint/README](../../packages/zperf/zperf-lint/README.md) |
| **cperf** | [c-performance-guide.md](../../packages/cperf/docs/zh-CN/c-performance-guide.md) | [corpus.md](../../packages/cperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/cperf/docs/zh-CN/evidence-policy.md) | `packages/cperf/cperf-lint/` |
| **jsperf** | [js-performance-guide.md](../../packages/jsperf/docs/zh-CN/js-performance-guide.md) | [corpus.md](../../packages/jsperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/jsperf/docs/zh-CN/evidence-policy.md) | `packages/jsperf/jsperf-lint/` |
| **jvmperf** | [en/](../../packages/jvmperf/docs/en/) | [corpus.md](../../packages/jvmperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/jvmperf/docs/zh-CN/evidence-policy.md) | `packages/jvmperf/jvmperf-lint/` |
| **goperf** | [go-performance-guide.md](../../packages/goperf/docs/zh-CN/go-performance-guide.md) | [corpus.md](../../packages/goperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/goperf/docs/zh-CN/evidence-policy.md) | `packages/goperf/goperf-lint/` |
| **pyperf** | [python-performance-guide.md](../../packages/pyperf/docs/zh-CN/python-performance-guide.md) | [corpus.md](../../packages/pyperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/pyperf/docs/zh-CN/evidence-policy.md) | `packages/pyperf/pyperf-lint/` |
| **swiftperf** | [swift-performance-guide.md](../../packages/swiftperf/docs/zh-CN/swift-performance-guide.md) | [corpus.md](../../packages/swiftperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/swiftperf/docs/zh-CN/evidence-policy.md) | `packages/swiftperf/swiftperf-lint/` |
| **arktsperf** | [arkts-performance-guide.md](../../packages/arktsperf/docs/zh-CN/arkts-performance-guide.md) | [corpus.md](../../packages/arktsperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/arktsperf/docs/zh-CN/evidence-policy.md) | `packages/arktsperf/arktsperf-lint/` |
| **cppperf** | [cpp-performance-guide.md](../../packages/cppperf/docs/zh-CN/cpp-performance-guide.md) | [corpus.md](../../packages/cppperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/cppperf/docs/zh-CN/evidence-policy.md) | `packages/cppperf/cppperf-lint/` |
| **csharpperf** | [csharp-performance-guide.md](../../packages/csharpperf/docs/zh-CN/csharp-performance-guide.md) | [corpus.md](../../packages/csharpperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/csharpperf/docs/zh-CN/evidence-policy.md) | `packages/csharpperf/csharpperf-lint/` |
| **phpperf** | [php-performance-guide.md](../../packages/phpperf/docs/zh-CN/php-performance-guide.md) | [corpus.md](../../packages/phpperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/phpperf/docs/zh-CN/evidence-policy.md) | `packages/phpperf/phpperf-lint/` |
| **rubyperf** | [ruby-performance-guide.md](../../packages/rubyperf/docs/zh-CN/ruby-performance-guide.md) | [corpus.md](../../packages/rubyperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/rubyperf/docs/zh-CN/evidence-policy.md) | `packages/rubyperf/rubyperf-lint/` |
| **rustperf** | [rust-performance-guide.md](../../packages/rustperf/docs/zh-CN/rust-performance-guide.md) | [corpus.md](../../packages/rustperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/rustperf/docs/zh-CN/evidence-policy.md) | `packages/rustperf/rustperf-lint/` |
| **kotlinperf** | [kotlin-performance-guide.md](../../packages/kotlinperf/docs/zh-CN/kotlin-performance-guide.md) | [corpus.md](../../packages/kotlinperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/kotlinperf/docs/zh-CN/evidence-policy.md) | `packages/kotlinperf/kotlinperf-lint/` |
| **objcperf** | [objc-performance-guide.md](../../packages/objcperf/docs/zh-CN/objc-performance-guide.md) | [corpus.md](../../packages/objcperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/objcperf/docs/zh-CN/evidence-policy.md) | `packages/objcperf/objcperf-lint/` |
| **dartperf** | [dart-performance-guide.md](../../packages/dartperf/docs/zh-CN/dart-performance-guide.md) | [corpus.md](../../packages/dartperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/dartperf/docs/zh-CN/evidence-policy.md) | `packages/dartperf/dartperf-lint/` |
| **luaperf** | [lua-performance-guide.md](../../packages/luaperf/docs/zh-CN/lua-performance-guide.md) | [corpus.md](../../packages/luaperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/luaperf/docs/zh-CN/evidence-policy.md) | `packages/luaperf/luaperf-lint/` |
| **beamperf** | [beam-performance-guide.md](../../packages/beamperf/docs/zh-CN/beam-performance-guide.md) | [corpus.md](../../packages/beamperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/beamperf/docs/zh-CN/evidence-policy.md) | `packages/beamperf/beamperf-lint/` |
| **nimperf** | [nim-performance-guide.md](../../packages/nimperf/docs/zh-CN/nim-performance-guide.md) | [corpus.md](../../packages/nimperf/docs/zh-CN/corpus.md) · [evidence-policy.md](../../packages/nimperf/docs/zh-CN/evidence-policy.md) | `packages/nimperf/nimperf-lint/` |

## 导航示意

```mermaid
flowchart TB
flowchart TB
  root[xperf]
  root[xperf]
  root --> readme["README.md<br/>family entry"]
  root --> readme["README.md<br/>family entry"]
  root --> docs["docs/<br/>overview · quickstart · kits<br/>playbook · smell catalog · rule regression<br/>roadmap · release · doc style"]
  root --> docs["docs/<br/>overview · quickstart · kits<br/>playbook · smell catalog · rule regression<br/>roadmap · release · doc style"]
  root --> kit["packages/kit/<br/>README · guide · corpus<br/>evidence/ · lint/"]
  root --> kit["packages/kit/<br/>README · guide · corpus<br/>evidence/ · lint/"]
```
