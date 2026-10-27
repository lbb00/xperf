# beamperf

> **Scope note:** **beamperf** covers **Elixir and Erlang** under one BEAM kit. Lint scans `.ex` / `.exs` / `.erl`. Prefer Elixir CLI; Erlang patterns are recognized in the same pass. Distinct from JVM kits.

Elixir + Erlang (BEAM) performance notes, small examples, and `beamperf-lint`.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). **Corpus-ready**. `be-list-concat-reduce`, `be-map-merge-hot` and `be-enum-map-filter-chain` **hint**; `be-io-puts-hot` **off**. One rule removed (tombstone, never got a slug). No G4. Guide v0.

## Contents

- [English guide (v0)](docs/beam-performance-guide.md) — from `docs/guide-src/`
- [`beamperf-lint`](beamperf-lint/README.md) — four rules (see its table for defaults)
- [Corpus pins](docs/corpus.md)

## Focus

Avoid `list ++` and string/`<>` growth in loops (prefer cons + reverse or iolist), keep `IO.puts` / `io:format` out of hot loops.

## Run lint

```sh
elixir packages/beamperf/beamperf-lint/beamperf_lint.exs path/to/sources
bash packages/beamperf/scripts/smoke-lint.sh
bash packages/beamperf/scripts/self-lint.sh
```

Exit `1` only for **error**-severity findings (hints exit `0` unless `--strict-hints`).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         per-rule measured evidence (*.md + *.jsonl) and _removed/ tombstones
examples/         tiny demos
beamperf-lint/    checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
