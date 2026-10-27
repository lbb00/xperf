# cperf

C11/C17 performance notes, small examples, and `cperf-lint` written in **C11**. Light C++ remarks appear where the same pattern applies.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). Severity presets. Guide v0. Wall-clock evidence gates `cp-alloc-hot`, `cp-realloc-grow-one` and `cp-printf-hot`; `cp-strlen-in-cond` (hint) and `cp-strcat-hot` (off) have none yet. `cp-sprintf-hot`, `cp-fopen-hot`, `cp-gettime-hot`, and `cp-wide-bool-flags` are hint with JSONL and are not corpus-triaged. `cp-regex-hot` is hint with JSONL (about 9.7×) and is not corpus-triaged. Corpus r1–r3 remains lint dogfood.

## Contents

- [English guide (v0)](docs/c-performance-guide.md) — from `docs/guide-src/`
- [`cperf-lint`](cperf-lint/README.md) — **C11** checker
- [Corpus pins](docs/corpus.md)

## Focus

Arenas / pools, capacity doubling, strlen-in-cond (cp-strlen-in-cond), hot-path stdio (cp-printf-hot), strcat-in-loop (cp-strcat-hot), formatted writes, file opens, clock samples in loops, and honest measurement notes. Claims without a local bench or citation stay provisional; corpus counts are lint dogfood.

## Build examples

```sh
cc -std=c17 -O2 -o /tmp/m01 examples/m01_arena.c && /tmp/m01
cc -std=c17 -O2 -o /tmp/p01 examples/p01_soa.c && /tmp/p01
```

## Run lint

```sh
cd packages/cperf/cperf-lint
make
./cperf-lint path/to/sources --preset app          # alloc/realloc=error; strlen, later hints, and cp-regex-hot=hint; printf/strcat=off
./cperf-lint path/to/sources --preset all          # every rule error
./cperf-lint path/to/sources --severity cp-printf-hot=off
make self-lint   # dogfood: lint src/ + include/, must be clean
make test        # fixtures + severity smoke + self-lint
```

From package root: `bash scripts/smoke-lint.sh`.

Exit code `1` only when an **error**-severity finding exists (hints print but exit `0` unless `--strict-hints`). Exit `2` on usage/IO errors.

## Layout

```text
docs/guide-src/   chapter sources (00_head … 04_hot_calls, 99_tail)
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         wall-clock gates: cp-alloc-hot, cp-realloc-grow-one, cp-printf-hot (*.md + *.jsonl)
examples/         tiny C demos + bench/ harnesses
cperf-lint/       C11 checker (src/, include/, Makefile) + fixtures
scripts/          regen-evidence-*.sh, run-static-vs-o2.sh
```
