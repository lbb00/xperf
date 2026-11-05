## 2. 字符串与热 I/O

循环里的 `a .. b` 会产生许多临时对象。优先收集片段再 `table.concat`。不要把 `print` 放进紧密循环（门控或缓冲）。

Lint: `lu-string-concat-hot`（default error); `lu-print-hot`（默认 hint）
