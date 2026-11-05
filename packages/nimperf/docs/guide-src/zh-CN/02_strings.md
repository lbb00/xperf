## 2. 字符串

在 Nim 2.2.12、`-d:release` 下，对 20000 片做 `&=` 比 `newSeq` 再 `join` 更快（约 0.79×）。建议改用 `join` 的 lint 已移除。见 `evidence/_removed/nm-string-amp-in-loop.REMOVED.md`。
