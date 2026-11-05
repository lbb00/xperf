## 1. 序列

已知长度或迭代次数时，优先 `newSeqOfCap` / `setLen` + 按索引写入。热循环里反复 `.add` 会重新分配。配套：**nm-seq-no-capacity**。

Lint: `nm-seq-add-hot`（默认 off，G3 后）; `nm-seq-no-capacity`（empty seq + `.add` size-hinted; 默认 hint）
