# rubyperf

Ruby performance notes, small examples, and `rubyperf-lint`.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). The lint is **corpus-ready** (heuristic). Defaults: rb-string-plus-in-loop, rb-array-plus-rebind, rb-puts-in-loop **off**; regexp / JSON / file-read **hint**. `rb-hash-merge-in-loop` was removed. Guide v0.

## Contents

- [English guide (v0)](docs/ruby-performance-guide.md) — from `docs/guide-src/`
- [`rubyperf-lint`](rubyperf-lint/README.md) — rb-string-plus-in-loop–rb-file-read-in-loop
- [Corpus pins](docs/corpus.md)

## Focus

Prefer `<<` over string `+=`, avoid Array `+` rebinding in loops, gate hot `puts`/`print`.

## Run lint

```sh
cd packages/rubyperf
ruby rubyperf-lint/rubyperf-lint.rb path/to/sources
bash scripts/smoke-lint.sh
bash scripts/self-lint.sh
```

Exit `1` only for **error**-severity findings (hints exit `0` unless `--strict-hints`).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         per-rule claim + measured JSONL (all four rules)
examples/         tiny demos
rubyperf-lint/    checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
