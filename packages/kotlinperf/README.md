# kotlinperf

> **Scope note:** **kotlinperf** is **Kotlin-first** (coroutines / collections / hot I/O smells). Sibling [jvmperf](../jvmperf/) remains the measured **JVM/Java(+Kotlin)** kit with JMH/JOL evidence — **do not duplicate JMH evidence here**; cross-link measured claims to jvmperf. This kit’s rules are heuristic and default to **off**.

Kotlin performance notes, small examples, and `kotlinperf-lint`.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). **Corpus-ready**. kt-list-add-hot–kt-println-hot **off**. One rule removed (tombstone, never got a slug). Guide v0.

## Contents

- [English guide (v0)](docs/kotlin-performance-guide.md) — from `docs/guide-src/`
- [`kotlinperf-lint`](kotlinperf-lint/README.md) — kt-list-add-hot / kt-string-plus-hot / kt-println-hot
- [Corpus pins](docs/corpus.md)

## Focus

Avoid repeated list alloc / string `+=` / `println` in hot loops; prefer builders and measured jvmperf guidance for JVM-wide claims.

## Run lint

```sh
cd packages/kotlinperf/kotlinperf-lint && bash build.sh
./kotlinperf-lint path/to/sources
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
kotlinperf-lint/  checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
