# objcperf

> **Scope note:** **objcperf** is **Objective-C** (MRC/ARC; `NSString` concat and `NSLog` in loops). Distinct from sibling [swiftperf](../swiftperf/). On Linux the checker is a **C line-window scanner** over `.m`/`.h` (clang builds the tool); full Apple runtime not required for lint.

Objective-C performance notes, small examples, and `objcperf-lint`.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). **Corpus-ready** for the 2026-10-22 rule set. oc-nsstring-append-hot / oc-nslog-hot **off** (measured, not escalated). Date-formatter, JSON, and regular-expression hints are pending measure and are not part of that verdict. Two rules removed (tombstone, never got a slug). Guide v0.

## Contents

- [English guide (v0)](docs/objc-performance-guide.md) — from `docs/guide-src/`
- [`objcperf-lint`](objcperf-lint/README.md) — two measured rules **off**; three hint rules pending measure; two rules removed (tombstone, never got a slug)
- [Corpus pins](docs/corpus.md)

## Focus

Pre-size `NSMutableArray`, avoid `stringByAppendingString` in loops (prefer `NSMutableString`), keep `NSLog` out of hot loops.

## Run lint

```sh
cd packages/objcperf/objcperf-lint && make
./objcperf-lint path/to/sources
bash ../scripts/smoke-lint.sh
bash ../scripts/self-lint.sh
```

Exit `1` only for **error**-severity findings (hints exit `0` unless `--strict-hints`).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         two measured rules (both off); three pending hint notes; OC001/OC004 tombstones
examples/         tiny demos
objcperf-lint/      checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
