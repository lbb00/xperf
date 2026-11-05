## 3. Formatter、JSON 与正则

循环里的 `[[NSDateFormatter alloc] init]`、`[NSDateFormatter new]`、`NSJSONSerialization`（`JSONObjectWithData` / `dataWithJSONObject`）以及 `NSRegularExpression`（`regularExpressionWithPattern`）每轮重复准备。formatter 或表达式只建一次；数据允许时，payload 只解析或编码一次。这些 lint 是 hint。各自有 JSONL 微基准并保持 hint。它们不属于 2026-10-22 corpus-ready 裁决。它们不会复活已移除的数组容量规则。

对同一路径 `stringWithContentsOfFile:` 约 450×（相对读一次）。每轮都变的路径不能外提。

每轮 `[NSDate date]` 相对采一次样约 769×。需要新鲜时间戳的循环没有可外提的东西。`NSDateFormatter` 仍是独立规则。

每轮 `valueForKey:` 相对读字段约 124×。不是固定字段的名字不能改写成直接读取。这与 Go 的 `FieldByName` 同族。

Lint: `oc-dateformatter-hot`, `oc-json-hot`, `oc-regex-hot`, `oc-file-read-hot`, `oc-clock-hot`, `oc-value-for-key-hot`（默认 hint）
