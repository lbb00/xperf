## 1. List

热循环里的 `List.add` 在容量摊销时可以接受，但每次迭代新建可增长 list 不行。尽可能用 `List.filled` / `List.generate` / 已知长度。

配套 lint：**dt-list-add-empty**、**dt-growable-add-empty**（空的可增长 list + 在有大小提示的循环里 `add`）。
