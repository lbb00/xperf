## 3. Formatter、JSON 与正则

`DateFormatter`、`JSONDecoder`、`NSRegularExpression` 准备很重。热循环每轮新建会重复该工作；只建一次并复用。`JSONSerialization.jsonObject` 归入 JSON 情形。Swift `Regex` 值是另一套 API，不标记。这些 lint 是 hint。各自有 JSONL 微基准并保持 hint。它们不属于 2026-10-22 corpus-ready 裁决。

对同一路径 `String(contentsOfFile:)` 约 414×（相对读一次）。每轮都变的路径不能外提。

每轮 `Date()` 相对采一次样约 244×。需要新鲜时间戳的循环没有可外提的东西。`DateFormatter` 仍是独立规则。

每轮 `value(forKey:)` 相对读属性约 35×。每轮都变的名字不能变成直接属性。这与 Go 的 `FieldByName` 同族。

Lint: `sp-dateformatter-hot`, `sp-json-decode-hot`, `sp-regex-hot`, `sp-file-read-hot`, `sp-clock-hot`, `sp-value-for-key-hot`（默认 hint）
