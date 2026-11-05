## 3. 物化与格式化

循环里的 `ToList` / `ToArray` / `ToDictionary` 每轮分配新集合。循环里的 `string.Format` 每轮分配新字符串。循环里的 `JsonSerializer.Serialize` / `Deserialize` 与 `JsonConvert.SerializeObject` / `DeserializeObject` 每轮编解码。`cs-json-hot` 保持 hint。微基准是固定 payload。它不属于 2026-10-22 corpus-ready 裁决。

对同一路径 `File.ReadAllText` 在 .NET 10 上约 338×（相对读一次）。`Stopwatch.GetTimestamp` 约 37×（相对采一次样）。每轮 `new Regex`（两侧仍匹配）约 7×，与静态 `Regex.IsMatch` 同为 hint。变化的路径不能外提；需要新鲜时间戳的循环也没有可外提的东西。

每轮 `GetField` 再 `GetValue` 相对直接读字段约 62×。持有 `FieldInfo` 仍调用 `GetValue` 约 42×，因此只把 `GetField` 挪到循环外改动很小。每轮都变的名字不能变成直接字段。这与 Go 的 `FieldByName` 同族。

Lint: `cs-linq-materialize-hot`, `cs-format-hot`（默认 hint; pending measure）; `cs-json-hot`, `cs-regex-hot`, `cs-file-read-hot`, `cs-clock-hot`, `cs-field-by-name-hot`（默认 hint）
