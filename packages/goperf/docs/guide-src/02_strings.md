## 2. Strings and formatting

Repeated `s += piece` in a loop is quadratic. Prefer `strings.Builder` or `bytes.Buffer`. Hot-path `fmt.Sprintf` / `fmt.Printf` also allocate; gate debug prints or use cheaper appenders when measured.

Companion lint: **gp-string-plus-in-loop**/**gp-fmt-in-loop** (off after G3), **gp-defer-in-loop** (`defer` in loop).

