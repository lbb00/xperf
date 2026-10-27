# rustperf

> **Scope note:** **rustperf** is dedicated **Rust** (edition 2021+). Heuristic lint only; measure with `criterion` / `cargo bench` before escalating.

Rust performance notes, small examples, and `rustperf-lint`.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). The lint is heuristic (**corpus-ready: yes** — r4 6×TP on clap; **rs-alloc-hot=off**; **rs-format-rebind-hot=error** ~99×; **rs-println-hot/rs-collect-vec-hot=hint**; all six rules have measured JSONL). Guide v0.

## Contents

- [English guide (v0)](docs/rust-performance-guide.md) — from `docs/guide-src/`
- [`rustperf-lint`](rustperf-lint/README.md) — rs-alloc-hot–rs-collect-vec-hot
- [Corpus pins](docs/corpus.md)

## Focus

Avoid alloc/clone in hot loops, prefer `with_capacity` before sized push loops, avoid per-iter `collect::<Vec<_>>`, prefer `write!` over `format!` rebind, keep `println!` out of tight loops.

## Run lint

```sh
cd packages/rustperf/rustperf-lint && cargo build --release
./target/release/rustperf-lint path/to/sources
bash ../scripts/smoke-lint.sh
bash ../scripts/self-lint.sh
```

Exit `1` only for **error**-severity findings (hints exit `0` unless `--strict-hints`).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         per-rule claim + measured JSONL; rs-format-rebind-hot error (~99×), others off/hint
examples/         tiny demos
rustperf-lint/    checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
