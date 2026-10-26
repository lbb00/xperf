## 2. Strings and hot I/O

`s = s + x` in a loop builds many strings. Prefer `StringBuffer`. Keep `print` out of tight loops.

Companion lint: **dt-string-plus-in-loop**, **dt-print-in-loop**.

