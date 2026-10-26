# csharpperf-lint

C# heuristic checker (requires `dotnet` SDK to build). Slugs are listed in [`../docs/rule-ids.md`](../docs/rule-ids.md). `cs-json-in-loop` is not part of the 2026-10-22 corpus-ready verdict.

| Rule | Default | Message |
|------|---------|---------|
| cs-list-add-no-capacity | **off** | `List.Add` in loop without Capacity / pre-size |
| cs-string-plus-in-loop | **off** | string `+=` in loop; prefer `StringBuilder` |
| cs-console-in-loop | **off** | `Console.Write*` in loop; gate or buffer |
| cs-regex-in-loop | **hint** | `Regex` in a loop; compile outside only when the pattern stays the same |
| cs-linq-materialize-in-loop | **hint** | `ToList` / `ToArray` / `ToDictionary` in loop; materialize once |
| cs-format-in-loop | **hint** | `string.Format` in loop; format outside or use a builder |
| cs-json-in-loop | **hint** | JSON encode or decode in a loop; hoist only when this value stays the same |

Smoke skips gracefully when `dotnet` is absent. Corpus-ready after G3 redesign — see [`../docs/corpus.md`](../docs/corpus.md).
