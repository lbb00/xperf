# beamperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.
Lint with:

```sh
elixir packages/beamperf/beamperf-lint/beamperf_lint.exs \
  <corpus-dir>/<name> --format json --no-fail
```

Checker is **Elixir/Erlang** (`beamperf-lint`). Rules: all four (see [rule-ids.md](rule-ids.md)).
Scans `.ex` / `.exs` / `.erl`.

## Pins

Cloned 2026-10-21 (Asia/Shanghai).

| Tree | Commit | Size | Lint (r2 → r3 redesign) |
|------|--------|------|-------------------------|
| **elixir** | `aad5397` shallow `https://github.com/elixir-lang/elixir.git` | 22M | **1 → 4** (be-map-merge-in-loop:3 be-enum-map-filter-chain:1) |
| **phoenix** | `e5880ef` shallow `https://github.com/phoenixframework/phoenix.git` | 7.6M | **0 → 0** |
| **cowboy** | `6475600` shallow `https://github.com/ninenines/cowboy.git` | 11M | **0 → 0** |

Path skips: `test(s)/`, `example(s)/`, `docs/`, `benchmark(s)/`, `_build/`,
`deps/`, `fixtures/`, `tmp/`, `scripts/`, `iex/`, `integration_test/`.

## G3 TP/FP triage (2026-10-22 Asia/Shanghai)

| | r1 n=70 | r2 n=1 | **r3 n=4** |
|--|---------|--------|------------|
| TP | 4.3% | 100% | **75%** |
| FP+DOC+SKIP | **64.3%** | 0% | **0%** |
| OK-idiom | 31.4% | 0% | 25% |

**Corpus-ready? `yes`** (r3 redesign). Defaults: `be-list-concat-reduce`, `be-map-merge-in-loop` and `be-enum-map-filter-chain` **hint**; `be-io-puts-in-loop` **off**. No G4 / no default `error`.

### Redesign (`beamperf-lint`)
- be-io-puts-in-loop → **off** (BE002 was retired); be-map-merge-in-loop merge-in-loop; be-enum-map-filter-chain Enum chain; Erlang `Acc ++ [` without loop head
- Elixir `%{}` no longer treated as Erlang `%` comment
