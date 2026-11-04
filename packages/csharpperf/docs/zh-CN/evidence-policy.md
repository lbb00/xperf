# csharpperf 证据政策

## 门槛

一条规则只有在有 `evidence/<RULE>.md` + `.jsonl` **以及**明确的政策决定的情况下，才可被视为 **`error`**。仅测量的 JSONL 并不会自动升级。Batch B（2026-10-22）保持了软件包默认设置。

## 当前映射

截至2026-10-22（B批次 G4）。

| 规则 | 严重性（默认） | 证据 | 异味 |
|------|--------------------|----------|-------|
| cs-list-add-no-capacity | 关闭 | **是** ~1.31× | 列表.Add 无容量 |
| cs-string-plus-hot | 关闭 | **是** ~3758× | string += |
| cs-console-hot | 关闭 | **是** ~6× | 循环中的控制台 |
| cs-regex-hot | 提示 | **是** ~2.6× | Regex.IsMatch |
| cs-linq-materialize-hot | 提示 | 已测量（`cs-linq-materialize-hot.md` + `cs-linq-materialize-hot.jsonl`）；保持提示 | 循环中的 `ToList` / `ToArray` / `ToDictionary`；未经过语料库筛选 |
| cs-format-hot | 提示 | 已测量（`cs-format-hot.md` + `cs-format-hot.jsonl`）；保持提示 | 循环中的 `string.Format`；未进行语料库筛选 |
| cs-json-hot | 提示 | 测量（`cs-json-hot.md` + `cs-json-hot.jsonl`）；保留提示 | 循环中的 JSON 编码/解码；仅固定有效负载；非语料库筛选 |
| cs-file-read-hot | 提示 | 测量 (`cs-file-read-hot.md` + `cs-file-read-hot.jsonl`); 保持提示 | 循环中使用 `File.ReadAllText` / `File.Open`; 仅相同路径; 未经过语料库筛选 |
| cs-clock-hot | 提示 | 测量（`cs-clock-hot.md` + `cs-clock-hot.jsonl`）；保持提示 | 循环中的 `Stopwatch.GetTimestamp`；未进行语料库分类 |
| cs-field-by-name-hot | 提示 | 测量 (`cs-field-by-name-hot.md` + `cs-field-by-name-hot.jsonl`); 保持提示 | 循环中的 `GetField` / `GetProperty`; 未经过语料库筛选 |
