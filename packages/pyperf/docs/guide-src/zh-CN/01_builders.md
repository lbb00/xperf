## 1. 字符串与列表

循环里的 `s += piece` 在 CPython 上是平方级的。优先 `''.join(...)` 或 `io.StringIO`。反复 `xs = xs + [item]` 同样会拷贝；优先 `append`。

配套 lint：**pp-str-plus-hot**、**pp-list-plus-rebind**。
