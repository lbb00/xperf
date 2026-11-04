## 序列

已知长度或迭代次数时，优先 `newSeqOfCap` / `setLen` + 按索引写入。热循环里反复 `.add` 会重新分配。配套：**nm-seq-no-capacity**。
