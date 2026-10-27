# dartperf

> **Scope note:** **dartperf** targets **Dart** (Flutter/VM). Heuristic lint; measure with `benchmark_harness` before escalating.

Dart performance notes, small examples, and `dartperf-lint`.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). **Corpus-ready**. dt-list-add-empty–dt-print-hot **off**; **dt-growable-add-empty** hint. Guide v0.

## Contents

- [English guide (v0)](docs/dart-performance-guide.md) — from `docs/guide-src/`
- [`dartperf-lint`](dartperf-lint/README.md) — dt-list-add-empty–dt-growable-add-empty
- [Corpus pins](docs/corpus.md)

## Focus

Prefer fixed-length / capacity-aware lists, avoid string `+` in loops (`StringBuffer`), keep `print` out of hot loops.

## Run lint

```sh
cd packages/dartperf/dartperf-lint && dart pub get
dart run bin/dartperf_lint.dart path/to/sources
bash ../scripts/smoke-lint.sh
bash ../scripts/self-lint.sh
```

Exit `1` only for **error**-severity findings (hints exit `0` unless `--strict-hints`).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         pending stubs until benches land
examples/         tiny demos
dartperf-lint/  checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
