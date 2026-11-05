# BEAM performance guide (v0) — Elixir & Erlang

Less quadratic list growth, fewer binary rebuilds, quieter hot loops.

> **Scope: Elixir 1.14+ and Erlang/OTP 25+ on BEAM.** One kit covers both languages. Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`:timer.tc`, `fprof`, `eprof`, `Benchee`). Extensions scanned: `.ex`, `.exs`, `.erl`.

## Contents

- [1. Lists](#1-lists)
- [2. Binaries / strings and hot I/O](#2-binaries--strings-and-hot-io)
- [Lint map](#lint-map)

