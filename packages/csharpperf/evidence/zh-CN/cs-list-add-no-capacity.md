# cs-list-add-no-capacity — List.Add 无需容量

**状态：** 已测量

## 主张

在 .NET 10.0.13 中，`new List<int>()` 然后添加 N 次大约是 `new List<int>(N)` 的 1.31 倍。之前一个繁忙机器的测试大约是 1.25 倍。随后在同一主机上的两次运行大约是 1.72 倍（0.462 毫秒 vs 0.269 毫秒，以及 0.426 毫秒 vs 0.248 毫秒）；没有容量的样本范围大约从 0.30 毫秒到 0.90 毫秒，因此这些运行不能替代下面的那行。之前约 13 倍的数据不是这次运行的。规则保持关闭。

## 如何测量

- 测试工具：`examples/bench/EvidenceCsBench`（`dotnet run -c Release`）
- N=200000

- 原始行: [`cs-list-add-no-capacity.jsonl`](../cs-list-add-no-capacity.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 UTC（linux x64，负载 0.58） |
| dotnet | **10.0.13** |
| 中位数之前 (`list_add_nocap`) | 0.4057 毫秒 |
| (`list_capacity`) 后的中位数 | 0.3101 毫秒 |
| **前后比例** | **~1.31×** |

## 与 lint 的对应

`csharpperf-lint` cs-list-add-no-capacity：保持默认严重性。

## 限制

- 默认保持**关闭**（G3）。
