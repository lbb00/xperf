# zperf

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md).

Zig performance guide, runnable examples, and the `zperf-lint` static checker.

**corpus-ready: yes**. G3/r4 triage demoted OK-idiom-mass rules; the default map keeps nine rules on: zp-page-allocator-small, zp-broad-runtime-safety, zp-static-string-map, zp-queue-ordered-remove, zp-shift-on-read, zp-invariant-float-div, zp-arena-reset-free-all, zp-create-destroy-in-loop and zp-fixed-size-alloc-in-loop. See [docs/corpus.md](docs/corpus.md).

Licensed under the [MIT License](../../LICENSE).

## Contents

- [English performance guide](docs/zig-performance-guide.md) — generated from `docs/guide-src/`.
- [Community tooling comparison](docs/community-tooling.md) — related Zig linters: scope and limits.
- [`zperf-lint` documentation](zperf-lint/README.md) — build, usage, rules, fixtures.
- [Corpus pins and G3 results](docs/corpus.md), [evidence policy](docs/evidence-policy.md), [rule ids](docs/rule-ids.md), [evidence notes](evidence/README.md).

## Focus

Allocation in loops, arena and fixed-size patterns, packed layouts, runtime safety checks, hot-path I/O, and honest measurement notes. Claims without a local bench or citation stay provisional.

## Run lint

Examples and `zperf-lint` target Zig 0.17.0. `zperf-lint` uses Zig's standard AST and has no third-party runtime dependencies.

The Zig package root is **`zperf-lint/`** (`build.zig` and `build.zig.zon` live there), not the `packages/zperf/` umbrella directory.

```sh
cd zperf-lint
zig build -Doptimize=fast
zig build test
zig-out/bin/zperf-lint ../examples
```

Findings are syntax-based heuristics without type information. Treat them as review prompts, not compiler diagnostics. See the tool docs for per-rule limits and suppressions.

Run community linters with the checker, from `packages/zperf/`:

```sh
zig run scripts/repo.zig -- lint-all
```

`lint-all` looks in `third-party/bin` by default. Override with `TOOLS`; override the checker binary with `ZPERF`.

## Examples and guide generation

Examples live in `examples/`:

```sh
cd examples && zig build test
```

The guide is generated from the chapter shards in `docs/guide-src/`. Edit the shards, then regenerate from the repository root:

```sh
bash scripts/build-guides.sh zperf
```

That writes `docs/zig-performance-guide.md`. `bash scripts/build-guides.sh --check zperf` fails when the guide and the shards disagree.

## Layout

```text
ci/                 Pointer to root `.github/workflows/ci.yml` (no nested Actions)
docs/               Guides, corpus pins, evidence policy, and guide-src chapters
evidence/           Wall-clock gates and per-rule notes (*.md + *.jsonl)
examples/           Runnable Zig examples referenced by the guide
scripts/            repo.zig (lint-all) and regen-evidence.sh
zperf-lint/         Checker package, tests, and fixtures
```

`zperf-lint/` and `examples/` are separate Zig build roots; build each from its own directory.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
