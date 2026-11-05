## 4. 循环中的查找与 JSON

热循环里对列表做 `Array.includes` / `indexOf` 是每次迭代线性扫描；先建一次 `Set` 再用 `has`。短字符串场景下，稠密查找表往往优于 `Map`（短 haystack 上 `Map` 常更慢）。在循环里反复 parse/stringify 许多小 JSON 会重复分配与解析；应解析一整块数组，或复用缓冲区。

Lint: `at-includes-hot`, `at-json-hot`（both 默认 hint）. Their JSONL evidence is a Node proxy, not an ArkTS VM, so it cannot raise severity on its own.
