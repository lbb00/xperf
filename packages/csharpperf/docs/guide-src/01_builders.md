## 1. Lists and strings

`List.Add` in a loop without setting `Capacity` reallocates. Prefer sizing once. String `+=` in a tight loop allocates; prefer `StringBuilder`.

Calling static `Regex.IsMatch` / `Regex.Match` with a pattern string on every iteration looks the pattern up in the static regex cache each time; prefer one reused `Regex` instance (`RegexOptions.Compiled` when the pattern is hot).

Companion lint: **cs-list-add-no-capacity**, **cs-string-plus-hot**, **cs-regex-hot**.

