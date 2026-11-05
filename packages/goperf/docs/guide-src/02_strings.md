## 2. Strings and formatting

Repeated `s += piece` in a loop is quadratic. Prefer `strings.Builder` or `bytes.Buffer`. Hot-path `fmt.Sprintf` / `fmt.Printf` also allocate; gate debug prints or use cheaper appenders when measured.

Lint: `gp-string-plus-hot`, `gp-fmt-hot` (default off after G3); `gp-defer-hot` (`defer` in loop; default hint).

