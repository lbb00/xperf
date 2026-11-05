## 1. List

热循环里的 `List.add` 在容量摊销时可以接受，但每次迭代新建可增长 list 不行。尽可能用 `List.filled` / `List.generate` / 已知长度。

Lint: `dt-list-add-empty`（默认 off）; `dt-growable-add-empty`（empty growable list + `add` in a size-hinted loop; 默认 hint）
