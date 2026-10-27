# C# performance guide (v0)

Fewer reallocating lists, quieter hot paths.

> **Scope: modern C# (.NET).** Claims that assert speedups name a local example or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## How to read this

1. **Measure first** (BenchmarkDotNet, `dotnet-trace`).
2. Treat each chapter as a checklist.
3. Runtime / GC settings differ — re-bench.

## Contents

- [How to read this](#how-to-read-this)
- [1. Lists and strings](#1-lists-and-strings)
- [2. Hot I/O](#2-hot-io)
- [Lint map](#lint-map)

## 1. Lists and strings

`List.Add` in a loop without setting `Capacity` reallocates. Prefer sizing once. String `+=` in a tight loop allocates; prefer `StringBuilder`.

Calling static `Regex.IsMatch` / `Regex.Match` with a pattern string on every iteration looks the pattern up in the static regex cache each time; prefer one reused `Regex` instance (`RegexOptions.Compiled` when the pattern is hot).

Companion lint: **cs-list-add-no-capacity**, **cs-string-plus-hot**, **cs-regex-hot**.

## 2. Hot I/O

`Console.Write` / `WriteLine` in a tight loop is expensive. Gate debug output or buffer.

Companion lint: **cs-console-hot**.

## 3. Materialize and format

`ToList` / `ToArray` / `ToDictionary` inside a loop allocates a fresh collection every iteration. `string.Format` inside a loop allocates a new string every iteration. `JsonSerializer.Serialize` / `Deserialize` and `JsonConvert.SerializeObject` / `DeserializeObject` inside a loop encode or decode on every iteration. `cs-json-hot` stays **hint**. The microbench is a fixed payload. It is not part of the 2026-10-22 corpus-ready verdict.

`File.ReadAllText` of one path was about 338× on .NET 10 versus reading once. `Stopwatch.GetTimestamp` was about 37× versus one sample. `new Regex` every iteration, with both sides still matching, was about 7× and is the same hint as the static `Regex.IsMatch` rule. A changing path cannot be hoisted, and a loop that needs a fresh timestamp has nothing to hoist.

`GetField` plus `GetValue` every iteration was about 62× versus reading the field. Holding the `FieldInfo` and still calling `GetValue` was about 42× versus the field, so moving only `GetField` outside is a small change. A name that changes every iteration cannot be turned into a direct field. This is the same family as Go `FieldByName`.

Companion lint: **cs-linq-materialize-hot**, **cs-format-hot**, **cs-json-hot**, **cs-regex-hot**, **cs-file-read-hot**, **cs-clock-hot**, **cs-field-by-name-hot**.

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| cs-list-add-no-capacity | `List.Add` in loop without Capacity | off |
| cs-string-plus-hot | string `+=` in loop | off |
| cs-console-hot | `Console.Write*` in loop | off |
| cs-regex-hot | static `Regex.IsMatch/Match` in loop | hint |
| cs-linq-materialize-hot | `ToList` / `ToArray` / `ToDictionary` in loop | hint (pending measure) |
| cs-format-hot | `string.Format` in loop | hint (pending measure) |
| cs-json-hot | JSON encode/decode in loop | hint (JSONL, fixed payload only) |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
