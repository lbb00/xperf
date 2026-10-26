# beamperf-lint

Heuristic Elixir + Erlang (BEAM) checker for the four rules below. Line/do-end window scanner — not a full AST pass.

| Rule | Default | Message |
|------|---------|---------|
| be-list-concat-reduce | hint | list ++ in loop (Elixir/Erlang; Erlang recursive Acc++ supported) |
| be-io-puts-in-loop | off | IO.puts / io:format in loop |
| be-map-merge-in-loop | hint | Map/Keyword.merge / maps:merge in loop |
| be-enum-map-filter-chain | hint | chained Enum.map/filter (intermediate list) |

Self-dogfood: `bash ../scripts/self-lint.sh` must stay clean on `examples/` (fixtures skipped).

## False positives

- Cold startup / config loops with tiny N (may be OK-idiom)
- Test / vendored / generated trees should be path-skipped

Removed (jitter 2026-10-22, no slug): `BE002` — see `evidence/_removed/`.
