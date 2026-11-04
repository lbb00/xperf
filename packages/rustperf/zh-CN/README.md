# rustperf

> **范围说明：** **rustperf** 专做 **Rust**（edition 2021+）。仅启发式 lint；升级前用 `criterion` / `cargo bench` 测量。

Rust 性能笔记、小示例，以及 `rustperf-lint`。

属于 [XPerf](../../../zh-CN/README.md)。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。lint 为启发式（**corpus-ready: 是** — r4 在 clap 上 6×TP；**rs-alloc-hot=off**；**rs-format-rebind-hot=error** ~99×；**rs-println-hot/rs-collect-vec-hot=hint**；六条规则均有实测 JSONL）。指南 v0。

## 目录

- [英文指南（v0）](../docs/zh-CN/rust-performance-guide.md) — 来自 `docs/guide-src/`
- [`rustperf-lint`](../rustperf-lint/README.md) — rs-alloc-hot–rs-collect-vec-hot
- [语料固定目标](../docs/zh-CN/corpus.md)

## 关注点

避免热循环里的 alloc/clone，有界 push 循环前优先 `with_capacity`，避免每轮 `collect::<Vec<_>>`，优先 `write!` 而非 `format!` 重绑定，紧循环里不要放 `println!`。

## 运行 lint

```sh
cd packages/rustperf/rustperf-lint && cargo build --release
cd packages/rustperf/rustperf-lint && cargo build --release
./target/release/rustperf-lint path/to/sources
./target/release/rustperf-lint path/to/sources
bash ../scripts/smoke-lint.sh
bash ../scripts/smoke-lint.sh
bash ../scripts/self-lint.sh
bash ../scripts/self-lint.sh
```

仅 **error** 级发现时退出 `1`（hint 退出 `0`，除非 `--strict-hints`）。

## 布局

```text
docs/guide-src/   章节源
docs/guide-src/   章节源
docs/             组装后的指南 + corpus.md + evidence-policy.md
docs/             组装后的指南 + corpus.md + evidence-policy.md
evidence/         每规则主张 + 实测 JSONL；rs-format-rebind-hot error（~99×），其余 off/hint
evidence/         每规则主张 + 实测 JSONL；rs-format-rebind-hot error（~99×），其余 off/hint
examples/         小演示
examples/         小演示
rustperf-lint/    检查器 + 夹具
rustperf-lint/    检查器 + 夹具
scripts/          smoke-lint.sh, self-lint.sh
scripts/          smoke-lint.sh, self-lint.sh
```
