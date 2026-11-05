# cs-regex-hot — 循环中的 Regex.IsMatch(pattern)

**状态：** 已测量

## 主张

在每次迭代中调用 `Regex.IsMatch(name, pattern)` 比使用一个 `RegexOptions.Compiled` 实例慢（在 .NET 10.0.13 上约为 2.58 倍）。

## 如何测量

- 测试工具：EvidenceCsBench
- N=50000；模式 `^[a-z]+$`

- 原始行: [`cs-regex-hot.jsonl`](../cs-regex-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| dotnet | **8.0.32** |
| 调用 `regex_ismatch_loop` 前的中位数 | 4.1372 毫秒 |
| (`compiled_regex`) 后的中位数 | 1.6045 毫秒 |
| **前/后比例** | **~2.58×** |

## 与 lint 的对应

`csharpperf-lint` cs-regex-hot：保持默认严重性。

## 限制

- 适度比例；默认保持 **提示**；仅凭约 2.6× 不要升级为错误。

## 构造函数形状

`new Regex` 每次迭代与使用一个实例。双方仍然在 `id-2026` 上调用 `IsMatch`。2000 次操作。之前 3.453 毫秒，之后 0.483 毫秒，比例 7.145。匹配器现在会标记 `new Regex(` 以及静态的 `Regex.IsMatch` / `Match` 调用。默认保持 **hint**。
