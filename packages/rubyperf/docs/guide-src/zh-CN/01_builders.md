## 1. 字符串、数组与哈希

`s += piece` 每次分配新字符串；优先 `s << piece`（或缓冲区）。`arr = arr + [x]` 会拷贝；优先 `<<` / `push`。

循环里的 `Hash#merge` 已移除。在 Ruby 4.0.8 上，建议的字面量构建比 `merge` 更慢（约 0.78×，再次约 0.65×），并大约多分配一倍对象。见 `evidence/_removed/rb-hash-merge-in-loop.REMOVED.md`。

Lint: `rb-string-plus-hot`, `rb-array-plus-rebind`（默认 off）
