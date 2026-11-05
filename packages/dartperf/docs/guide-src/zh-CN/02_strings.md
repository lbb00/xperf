## 2. 字符串与热 I/O

循环里的 `s = s + x` 会造出许多字符串。优先 `StringBuffer`。不要把 `print` 放进紧密循环。

Lint: `dt-string-plus-hot`, `dt-print-hot`（默认 off）
