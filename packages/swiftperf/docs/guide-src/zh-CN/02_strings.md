## 2. 字符串、集合与打印

反复 `s += piece` 可能昂贵；测得需要时优先预留容量 / builder。热路径 `print` 受 I/O 限制——请门控。在有大小的循环里向空 `Array` 追加会边长边扩容；已知最终计数时先 `reserveCapacity`。

配套 lint：**sp-print-hot**（off；丢弃 stdout 时相对 `String` 约 10×）、**sp-array-no-reserve**（hint；许多小数组约 5×，一次大填充约 1.6×）。带 `reserveCapacity` 的字符串 `+=` 更慢，`map` 再 `joined` 约 1.2×，因此那些 lint 已移除。
