## 2. 字符串、集合与打印

反复 `s += piece` 可能昂贵；测得需要时优先预留容量 / builder。热路径 `print` 受 I/O 限制——请门控。在有大小的循环里向空 `Array` 追加会边长边扩容；已知最终计数时先 `reserveCapacity`。

Lint: `sp-print-hot`（默认 off; about 10× a `String` when stdout is discarded）; `sp-array-no-reserve`（默认 hint; about 5× on many small arrays, about 1.6× on one large fill）. String `+=` with `reserveCapacity` was slower, and `map` then `joined` was about 1.2×, so those lints were removed.
