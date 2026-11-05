# BEAM 性能指南（v0）— Elixir 与 Erlang

少做平方级 list 增长，少重建 binary，让热循环更安静。

> **范围：Elixir 1.14+ 与 Erlang/OTP 25+（BEAM）。** 一个 kit 覆盖两种语言。加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（`:timer.tc`、`fprof`、`eprof`、`Benchee`）。扫描扩展名：`.ex`、`.exs`、`.erl`。

## 目录

- [1. List](#1-list)
- [2. Binary / 字符串与热 I/O](#2-binary--字符串与热-io)
- [Lint 对照](#lint-对照)

## 1. List

循环里的 `list ++ [x]`（Elixir）或 `List ++ [X]`（Erlang）是平方级的。优先 `[x | acc]` 再 `Enum.reverse/1` / `lists:reverse/1`，或使用正确的累加器。

在 reduce 的每个元素上调用 `Map.merge/2` 或 `Keyword.merge/2`，测得比 `Map.put/3` 更慢（见 [evidence-policy.md](evidence-policy.md)）。用 `Map.put/3`；仅当另一 map 不变时，才在循环外 merge。链式 `Enum.map/2` 再 `Enum.filter/2` 会建中间 list。约 200000 整数的测量链大约 4.5×；短 list 成本不同。

Lint: `be-list-concat-reduce`, `be-map-merge-hot`, `be-enum-map-filter-chain`（all 默认 hint）
## 2. Binary / 字符串与热 I/O

循环里的 `a <> b`（Elixir）或反复 binary 追加会重建 binary。优先 iolist / `IO.iodata_to_binary/1`。没有 lint 覆盖该 smell（旧规则 `BE002` 已退役）。不要把 `IO.puts` / `:io.format` / `io:format` 放进紧密循环。

Lint: `be-io-puts-hot`（默认 off）
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| be-list-concat-reduce | 循环内 list `++` | hint |
| be-map-merge-hot | 循环内 `Map`/`Keyword.merge` | hint |
| be-enum-map-filter-chain | 链式 `Enum.map`/`filter` | hint |
| be-io-puts-hot | 循环内 `IO.puts` / `io:format` | off |

仅在有 `evidence/be-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
