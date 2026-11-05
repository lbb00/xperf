## 2. Binary / 字符串与热 I/O

循环里的 `a <> b`（Elixir）或反复 binary 追加会重建 binary。优先 iolist / `IO.iodata_to_binary/1`。没有 lint 覆盖该 smell（旧规则 `BE002` 已退役）。不要把 `IO.puts` / `:io.format` / `io:format` 放进紧密循环。

Lint: `be-io-puts-hot`（默认 off）
