# zperf

属于 [XPerf](../../../zh-CN/README.md)。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。

Zig 性能指南、可运行示例，以及 `zperf-lint` 静态检查器。

**corpus-ready: 是**。G3/r4 triage 下调了 OK-idiom 大量命中的规则；默认映射保持九条开启：zp-page-allocator-small、zp-broad-runtime-safety、zp-static-string-map、zp-queue-ordered-remove、zp-shift-on-read、zp-invariant-float-div、zp-arena-reset-free-all、zp-create-destroy-hot 与 zp-fixed-size-alloc-hot。见 [docs/corpus.md](../docs/zh-CN/corpus.md)。

许可：[MIT License](../../../LICENSE)。

## 目录

- [英文性能指南](../docs/zh-CN/zig-performance-guide.md) — 由 `docs/guide-src/` 生成。
- [社区工具对比](../docs/zh-CN/community-tooling.md) — 相关 Zig linter：范围与限制。
- [`zperf-lint` 文档](../zperf-lint/README.md) — 构建、用法、规则、夹具。
- [语料固定目标与 G3 结果](../docs/zh-CN/corpus.md)、[证据策略](../docs/zh-CN/evidence-policy.md)、[规则 ID](../docs/zh-CN/rule-ids.md)、[证据笔记](../evidence/zh-CN/README.md)。

## 关注点

循环内分配、arena 与定长模式、packed 布局、运行时安全检查、热路径 I/O，以及诚实的测量说明。没有本地基准或引用的主张保持暂定。

## 运行 lint

示例与 `zperf-lint` 面向 Zig 0.17.0。`zperf-lint` 使用 Zig 标准 AST，无第三方运行时依赖。

Zig 包根是 **`zperf-lint/`**（`build.zig` 与 `build.zig.zon` 在那里），不是 `packages/zperf/` 伞目录。

```sh
cd zperf-lint
zig build -Doptimize=fast
zig build test
zig-out/bin/zperf-lint ../examples
```

发现是无类型信息的基于语法的启发式。把它们当评审提示，不是编译器诊断。每规则限制与抑制见工具文档。

从 `packages/zperf/` 与检查器一起跑社区 linter：

```sh
zig run scripts/repo.zig -- lint-all
```

`lint-all` 默认看 `third-party/bin`。用 `TOOLS` 覆盖；用 `ZPERF` 覆盖检查器二进制。

## 示例与指南生成

示例在 `examples/`：

```sh
cd examples && zig build test
```

指南由 `docs/guide-src/` 章节分片生成。编辑分片后，从仓库根重新生成：

```sh
bash scripts/build-guides.sh zperf
```

这会写出 `docs/zig-performance-guide.md`。当指南与分片不一致时，`bash scripts/build-guides.sh --check zperf` 失败。

## 布局

```text
ci/                 指向根 `.github/workflows/ci.yml` 的指针（无嵌套 Actions）
docs/               指南、语料固定目标、证据策略，以及 guide-src 章节
evidence/           墙钟门禁与每规则笔记（*.md + *.jsonl）
examples/           指南引用的可运行 Zig 示例
scripts/            repo.zig（lint-all）与 regen-evidence.sh
zperf-lint/         检查器包、测试与夹具
```

`zperf-lint/` 与 `examples/` 是分开的 Zig 构建根；各自在其目录下构建。

## 参与贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。
