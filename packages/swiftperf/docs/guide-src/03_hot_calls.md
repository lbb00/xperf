## 3. Formatters, JSON, and regular expressions

`DateFormatter`, `JSONDecoder`, and `NSRegularExpression` do heavy setup. Building one on every iteration of a hot loop repeats that work; create it once and reuse it. `JSONSerialization.jsonObject` belongs with the JSON case. A Swift `Regex` value is a different API and is not flagged. These lints are **hint**. Each has a JSONL microbench and stays hint. They are not part of the 2026-10-22 corpus-ready verdict.

`String(contentsOfFile:)` of one path was about 414× versus reading once. A path that changes every iteration cannot be hoisted.

`Date()` every iteration was about 244× versus one sample. A loop that needs a fresh timestamp has nothing to hoist. `DateFormatter` stays its own rule.

`value(forKey:)` every iteration was about 35× versus reading the property. A name that changes every iteration cannot become a direct property. This is the same family as Go `FieldByName`.

Companion lint: **sp-dateformatter-hot**, **sp-json-decode-hot**, **sp-regex-hot**, **sp-file-read-hot**, **sp-clock-hot**, **sp-value-for-key-hot**.
