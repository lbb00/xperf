# cppperf

> **Scope note:** **cppperf** is dedicated **C++17**. Sibling [cperf](../cperf/) remains **C11/C17** (+ light C++). Do not merge the two kits.

C++17 performance notes, small examples, and `cppperf-lint`.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). **Corpus-ready** for the 2026-10-22 rule set. regex, endl, clock, ifstream, const-by-value, and vector-bool hints with JSONL. String append and string-stream were removed. Three older rules removed (tombstone, never got a slug). Guide v0 scaffold.

## Contents

- [English guide (v0)](docs/cpp-performance-guide.md) — from `docs/guide-src/`
- [`cppperf-lint`](cppperf-lint/README.md) — string append, regex, endl, and clock hints; three rules removed (tombstone, never got a slug)
- [Corpus pins](docs/corpus.md)

## Focus

Reserve before hot `push_back`, avoid quadratic string growth, keep `iostream` out of tight loops (prefer buffered/`fmt` outside).

## Run lint

```sh
cd packages/cppperf/cppperf-lint && make
./cppperf-lint path/to/sources
bash ../scripts/smoke-lint.sh
bash ../scripts/self-lint.sh
```

Exit `1` only for **error**-severity findings (hints exit `0` unless `--strict-hints`).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         measured JSONL; _removed/ tombstones including cx-string-append-unreserved
examples/         tiny demos
cppperf-lint/    checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
