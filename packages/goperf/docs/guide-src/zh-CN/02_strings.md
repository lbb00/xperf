## 2. 字符串与格式化

循环里反复 `s += piece` 是平方级的。优先 `strings.Builder` 或 `bytes.Buffer`。热路径上的 `fmt.Sprintf` / `fmt.Printf` 也会分配；门控调试打印，或在测得更便宜时改用更轻的 appender。

Lint: `gp-string-plus-hot`, `gp-fmt-hot`（默认 off，G3 后）; `gp-defer-hot`（循环内 `defer`；默认 hint）
