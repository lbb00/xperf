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

## 1. Lists

`list ++ [x]` (Elixir) or `List ++ [X]` (Erlang) in a loop is quadratic. Prefer `[x | acc]` then `Enum.reverse/1` / `lists:reverse/1`, or use proper accumulators.

`Map.merge/2` or `Keyword.merge/2` on every element of a reduce was measured slower than `Map.put/3` (see [evidence-policy.md](evidence-policy.md)). Use `Map.put/3`, or merge outside only when the other map stays the same. Chained `Enum.map/2` then `Enum.filter/2` builds an intermediate list. On the measured chain of about 200000 integers that was about 4.5×; a short list is a different cost.

Companion lint: **be-list-concat-reduce**, **be-map-merge-in-loop**, **be-enum-map-filter-chain** (all default **hint**).

## 2. Binaries / strings and hot I/O

`a <> b` (Elixir) or repeated binary append in a loop rebuilds binaries. Prefer iolists / `IO.iodata_to_binary/1`. No lint rule covers this smell (its former rule, `BE002`, was retired). Keep `IO.puts` / `:io.format` / `io:format` out of tight loops.

Companion lint: **be-io-puts-in-loop** (default **off**).

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| be-list-concat-reduce | list `++` in loop | hint |
| be-map-merge-in-loop | `Map`/`Keyword.merge` in loop | hint |
| be-enum-map-filter-chain | chained `Enum.map`/`filter` | hint |
| be-io-puts-in-loop | `IO.puts` / `io:format` in loop | off |

Escalate only with `evidence/be-*.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
