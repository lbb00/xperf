## 1. Strings and lists

`s += piece` in a loop is quadratic on CPython. Prefer `''.join(...)` or `io.StringIO`. Repeated `xs = xs + [item]` similarly copies; prefer `append`.

Companion lint: **pp-str-plus-hot**, **pp-list-plus-rebind**.

