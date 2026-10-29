## 3. Materialize and format

`ToList` / `ToArray` / `ToDictionary` inside a loop allocates a fresh collection every iteration. `string.Format` inside a loop allocates a new string every iteration. `JsonSerializer.Serialize` / `Deserialize` and `JsonConvert.SerializeObject` / `DeserializeObject` inside a loop encode or decode on every iteration. `cs-json-hot` stays **hint**. The microbench is a fixed payload. It is not part of the 2026-10-22 corpus-ready verdict.

`File.ReadAllText` of one path was about 338× on .NET 10 versus reading once. `Stopwatch.GetTimestamp` was about 37× versus one sample. `new Regex` every iteration, with both sides still matching, was about 7× and is the same hint as the static `Regex.IsMatch` rule. A changing path cannot be hoisted, and a loop that needs a fresh timestamp has nothing to hoist.

`GetField` plus `GetValue` every iteration was about 62× versus reading the field. Holding the `FieldInfo` and still calling `GetValue` was about 42× versus the field, so moving only `GetField` outside is a small change. A name that changes every iteration cannot be turned into a direct field. This is the same family as Go `FieldByName`.

Companion lint: **cs-linq-materialize-hot**, **cs-format-hot**, **cs-json-hot**, **cs-regex-hot**, **cs-file-read-hot**, **cs-clock-hot**, **cs-field-by-name-hot**.

