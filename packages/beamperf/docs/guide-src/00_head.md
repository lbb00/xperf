# BEAM performance guide (v0) — Elixir & Erlang

Less quadratic list growth, fewer binary rebuilds, quieter hot loops.

> **Scope: Elixir 1.14+ and Erlang/OTP 25+ on BEAM.** One kit covers both languages. Claims that assert speedups name a local example or are provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## How to read this

1. **Measure first** (`:timer.tc`, `fprof`, `eprof`, `Benchee`).
2. Treat each chapter as a checklist, not a rewrite mandate.
3. Extensions scanned: `.ex`, `.exs`, `.erl`.

## Contents

- [How to read this](#how-to-read-this)
- [1. Lists](#1-lists)
- [2. Binaries / strings and hot I/O](#2-binaries--strings-and-hot-io)
- [Lint map](#lint-map)

