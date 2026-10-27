# csharpperf evidence policy

## Gate

A rule may be treated as **`error`** only with `evidence/<RULE>.md` + `.jsonl` **and** an explicit policy decision. Measured JSONL alone does **not** auto-escalate. Batch B (2026-10-22) kept package defaults.

## Current map

As of 2026-10-22 (Batch B G4).

| Rule | Severity (default) | Evidence | Smell |
|------|--------------------|----------|-------|
| cs-list-add-no-capacity | off | **yes** ~1.31× | List.Add no Capacity |
| cs-string-plus-hot | off | **yes** ~3758× | string += |
| cs-console-hot | off | **yes** ~6× | Console in loop |
| cs-regex-hot | hint | **yes** ~2.6× | Regex.IsMatch |
| cs-linq-materialize-hot | hint | measured (`cs-linq-materialize-hot.md` + `cs-linq-materialize-hot.jsonl`); stay hint | `ToList` / `ToArray` / `ToDictionary` in loop; not corpus-triaged |
| cs-format-hot | hint | measured (`cs-format-hot.md` + `cs-format-hot.jsonl`); stay hint | `string.Format` in loop; not corpus-triaged |
| cs-json-hot | hint | measured (`cs-json-hot.md` + `cs-json-hot.jsonl`); stay hint | JSON encode/decode in loop; fixed payload only; not corpus-triaged |
| cs-file-read-hot | hint | measured (`cs-file-read-hot.md` + `cs-file-read-hot.jsonl`); stay hint | `File.ReadAllText` / `File.Open` in a loop; same path only; not corpus-triaged |
| cs-clock-hot | hint | measured (`cs-clock-hot.md` + `cs-clock-hot.jsonl`); stay hint | `Stopwatch.GetTimestamp` in a loop; not corpus-triaged |
| cs-field-by-name-hot | hint | measured (`cs-field-by-name-hot.md` + `cs-field-by-name-hot.jsonl`); stay hint | `GetField` / `GetProperty` in a loop; not corpus-triaged |
