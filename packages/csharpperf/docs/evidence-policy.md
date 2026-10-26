# csharpperf evidence policy

## Gate

A rule may be treated as **`error`** only with `evidence/<RULE>.md` + `.jsonl` **and** an explicit policy decision. Measured JSONL alone does **not** auto-escalate. Batch B (2026-10-22) kept package defaults.

## Current map

As of 2026-10-22 (Batch B G4).

| Rule | Severity (default) | Evidence | Smell |
|------|--------------------|----------|-------|
| cs-list-add-no-capacity | off | **yes** ~1.31× | List.Add no Capacity |
| cs-string-plus-in-loop | off | **yes** ~3758× | string += |
| cs-console-in-loop | off | **yes** ~6× | Console in loop |
| cs-regex-in-loop | hint | **yes** ~2.6× | Regex.IsMatch |
| cs-linq-materialize-in-loop | hint | measured (`cs-linq-materialize-in-loop.md` + `cs-linq-materialize-in-loop.jsonl`); stay hint | `ToList` / `ToArray` / `ToDictionary` in loop; not corpus-triaged |
| cs-format-in-loop | hint | measured (`cs-format-in-loop.md` + `cs-format-in-loop.jsonl`); stay hint | `string.Format` in loop; not corpus-triaged |
| cs-json-in-loop | hint | measured (`cs-json-in-loop.md` + `cs-json-in-loop.jsonl`); stay hint | JSON encode/decode in loop; fixed payload only; not corpus-triaged |
| cs-file-read-in-loop | hint | measured (`cs-file-read-in-loop.md` + `cs-file-read-in-loop.jsonl`); stay hint | `File.ReadAllText` / `File.Open` in a loop; same path only; not corpus-triaged |
| cs-clock-in-loop | hint | measured (`cs-clock-in-loop.md` + `cs-clock-in-loop.jsonl`); stay hint | `Stopwatch.GetTimestamp` in a loop; not corpus-triaged |
| cs-field-by-name-in-loop | hint | measured (`cs-field-by-name-in-loop.md` + `cs-field-by-name-in-loop.jsonl`); stay hint | `GetField` / `GetProperty` in a loop; not corpus-triaged |
