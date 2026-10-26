# phpperf

PHP performance notes, small examples, and `phpperf-lint`.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). Heuristic lint (**corpus-ready: yes**; **ph-array-merge-rebind=error** with G4; **ph-string-dot-in-loop=off**; ph-echo-in-loop=hint). Guide v0.

## Contents

- [English guide (v0)](docs/php-performance-guide.md) — from `docs/guide-src/`
- [`phpperf-lint`](phpperf-lint/README.md) — ph-string-dot-in-loop–ph-echo-in-loop
- [Corpus pins](docs/corpus.md)

## Focus

Avoid quadratic string growth (`.=`), prefer push over `array_merge` rebinding, gate hot `echo`/`print`.

## Run lint

```sh
cd packages/phpperf
php phpperf-lint/phpperf-lint.php path/to/sources
bash scripts/smoke-lint.sh
bash scripts/self-lint.sh
```

Exit `1` only for **error**-severity findings (hints exit `0` unless `--strict-hints`).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         ph-array-merge-rebind measured (error); ph-string-dot-in-loop measured (off); ph-echo-in-loop measured (hint)
examples/         tiny demos
phpperf-lint/      checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
