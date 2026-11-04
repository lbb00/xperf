# C# 性能指南（v0）

少做会重新分配的 list，让热路径更安静。

> **范围：现代 C#（.NET）。** 声称加速的断言会点名本地示例，或标明暂定。**Corpus lint 计数是启发式 dogfood**，不是基准。

## 如何阅读

1. 先**测量**（BenchmarkDotNet、`dotnet-trace`）。
2. 把每一章当核对清单。
3. 运行时 / GC 设置不同——请重测。

## 目录

- [如何阅读](#如何阅读)
- [1. List 与字符串](#1-list-与字符串)
- [2. 热 I/O](#2-热-io)
- [Lint 对照](#lint-对照)
## 1. List 与字符串

循环里的 `List.Add` 若不设 `Capacity` 会反复扩容。优先一次定容。紧密循环里的字符串 `+=` 会分配；优先 `StringBuilder`。

每轮调用静态 `Regex.IsMatch` / `Regex.Match` 并传入模式字符串，都会在静态正则缓存里查找；优先复用一个 `Regex` 实例（热模式可用 `RegexOptions.Compiled`）。

配套 lint：**cs-list-add-no-capacity**、**cs-string-plus-hot**、**cs-regex-hot**。
## 2. 热 I/O

紧密循环里的 `Console.Write` / `WriteLine` 很贵。门控调试输出或做缓冲。

配套 lint：**cs-console-hot**。
## 3. 物化与格式化

循环里的 `ToList` / `ToArray` / `ToDictionary` 每轮分配新集合。循环里的 `string.Format` 每轮分配新字符串。循环里的 `JsonSerializer.Serialize` / `Deserialize` 与 `JsonConvert.SerializeObject` / `DeserializeObject` 每轮编解码。`cs-json-hot` 保持 **hint**。微基准是固定 payload。它不属于 2026-10-22 corpus-ready 裁决。

对同一路径 `File.ReadAllText` 在 .NET 10 上约 338×（相对读一次）。`Stopwatch.GetTimestamp` 约 37×（相对采一次样）。每轮 `new Regex`（两侧仍匹配）约 7×，与静态 `Regex.IsMatch` 同为 hint。变化的路径不能外提；需要新鲜时间戳的循环也没有可外提的东西。

每轮 `GetField` 再 `GetValue` 相对直接读字段约 62×。持有 `FieldInfo` 仍调用 `GetValue` 约 42×，因此只把 `GetField` 挪到循环外改动很小。每轮都变的名字不能变成直接字段。这与 Go 的 `FieldByName` 同族。

配套 lint：**cs-linq-materialize-hot**、**cs-format-hot**、**cs-json-hot**、**cs-regex-hot**、**cs-file-read-hot**、**cs-clock-hot**、**cs-field-by-name-hot**。
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| cs-list-add-no-capacity | 循环内无 Capacity 的 `List.Add` | off |
| cs-string-plus-hot | 循环内字符串 `+=` | off |
| cs-console-hot | 循环内 `Console.Write*` | off |
| cs-regex-hot | 循环内静态 `Regex.IsMatch/Match` | hint |
| cs-linq-materialize-hot | 循环内 `ToList` / `ToArray` / `ToDictionary` | hint（待测） |
| cs-format-hot | 循环内 `string.Format` | hint（待测） |
| cs-json-hot | 循环内 JSON 编解码 | hint（有 JSONL，仅固定 payload） |

仅在有 `evidence/<rule>.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
