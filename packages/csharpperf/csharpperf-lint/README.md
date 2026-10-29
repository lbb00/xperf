# csharpperf-lint

C# heuristic checker (requires `dotnet` SDK to build). Slugs are listed in [`../docs/rule-ids.md`](../docs/rule-ids.md). `cs-json-hot` is not part of the 2026-10-22 corpus-ready verdict.

| Rule | Default | Message |
|------|---------|---------|
| cs-list-add-no-capacity | **off** | `List.Add` in loop without Capacity / pre-size |
| cs-string-plus-hot | **off** | string `+=` in loop; prefer `StringBuilder` |
| cs-console-hot | **off** | `Console.Write*` in loop; gate or buffer |
| cs-regex-hot | **hint** | `Regex` in a loop; compile outside only when the pattern stays the same |
| cs-linq-materialize-hot | **hint** | `ToList` / `ToArray` / `ToDictionary` in loop; materialize once |
| cs-format-hot | **hint** | `string.Format` in loop; format outside or use a builder |
| cs-json-hot | **hint** | JSON encode or decode in a loop; hoist only when this value stays the same |

Smoke skips gracefully when `dotnet` is absent. Corpus-ready after G3 redesign — see [`../docs/corpus.md`](../docs/corpus.md).
