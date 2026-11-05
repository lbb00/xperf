## 2. 字符串与热 I/O

循环里的 `s += x` 是经典 builder 场景（`StringBuilder` / `buildString`）。不要把 `println` 放进紧密循环。有测量的字符串拼接见 jvmperf `jp-string-concat-hot`。

Lint: `kt-string-plus-hot`, `kt-println-hot`（默认 off）
