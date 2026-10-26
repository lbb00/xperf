# jvmperf

JVM (Java / Kotlin) performance notes, runnable examples, JMH/JOL benches, and `jvmperf-lint` written in **Java**.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). **Corpus-ready**. Small evidence JSONL lives under `evidence/`.

## Contents

- [English guide](docs/en/performance-guide.md) — from `docs/guide-src/en/`
- [`jvmperf-lint`](jvmperf-lint/) — **Java** checker (Gradle, tree-sitter)
- [Corpus pins](docs/corpus.md)
- [Evidence pointers](evidence/README.md) · [evidence-policy](docs/evidence-policy.md)
- HotSpot correlate: `scripts/run-static-vs-hotspot.sh`

## Focus

Allocation / boxing, layout (SoA, primitive maps), hot-path strings & I/O, JIT/false-sharing/virtual threads, Kotlin sequences & inline. Claims without a local bench or citation stay provisional; corpus counts are lint dogfood.

## Requirements

- **JDK 21** to build and test `jvmperf-lint` (CI: Temurin 21). Pin `JAVA_HOME` to 21 — a host JDK 25 alone can make Gradle fail with an opaque `25.0.x` message. The project uses a Java **21** toolchain + Foojay resolver.
- **JDK 25** optional for JMH/JOL examples and benches (separate `JAVA_HOME` when running those scripts)
- Kotlin 2.4.x for Kotlin examples (`scripts/check_kotlin.sh`)
- Optional jars in `lib/` — **not in git**; `bash scripts/fetch-lib.sh` (see `lib/README.md`). Default `JVMPERF_LIB_DIR=$ROOT/lib`

## Run lint

```sh
cd packages/jvmperf/jvmperf-lint
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
./gradlew test jar
bin/jvmperf-lint ../examples --no-fail
bin/jvmperf-lint --list-rules
```

Exit code `1` when findings exist (unless `--no-fail`). Exit `2` on usage/IO errors.

**Severity note:** process exit still treats any finding as failure unless `--no-fail`. Each rule's default severity (`error`, `hint`, or `off`) follows `docs/evidence-policy.md`; rules marked `off` do not run unless selected with `--enable` (which then runs only the listed rules). Full `--preset` wiring may land later.

Self-check: `./gradlew test` (fixtures + unit). Dogfood examples with `--no-fail` as review prompts.

## Benches & checks

```sh
# From packages/jvmperf: rebuild guides from docs/guide-src (code samples are inlined in the chapter files)
bash ../../scripts/build-guides.sh jvmperf
scripts/check_java.sh
scripts/check_kotlin.sh
# JMH / JOL / Kotlin alloc (writes JSONL under research/bench-results):
# scripts/run_jmh.sh …
# scripts/run_jol_maps.sh
# scripts/run_kotlin_alloc.sh
```

## Layout

```text
docs/guide-src/     chapter sources (en/, zh-CN/)
docs/               assembled guides + corpus.md
examples/           java + kotlin (+ android fixtures)
jvmperf-lint/       Java checker (Gradle) + fixtures
jmh-benches/        JMH sources
lib/                optional jars (gitignored; fetch-lib.sh)
research/           small in-tree Jol/EA probe sources (no *.log dumps)
scripts/            run_*, check_*, env.sh (build_guide is superseded by the repo-level scripts/build-guides.sh)
evidence/           pointers to research JSONL (not full dumps)
```
