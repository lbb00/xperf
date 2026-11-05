## 1. Strings and lists

`s += piece` in a loop is quadratic on CPython. Prefer `''.join(...)` or `io.StringIO`. Repeated `xs = xs + [item]` similarly copies; prefer `append`.

Lint: `pp-str-plus-hot` (default off after G3); `pp-list-plus-rebind` (default hint).

