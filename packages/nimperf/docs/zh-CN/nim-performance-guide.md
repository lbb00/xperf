# Nim 性能指南（v0）

由 `docs/guide-src/` 组装。脚手架——不是有测量支撑的手册。启发式 kit——把 lint 升为 error 前请先测量。
## 序列

已知长度或迭代次数时，优先 `newSeqOfCap` / `setLen` + 按索引写入。热循环里反复 `.add` 会重新分配。配套：**nm-seq-no-capacity**。
## 字符串

在 Nim 2.2.12、`-d:release` 下，对 20000 片做 `&=` 比 `newSeq` 再 `join` 更快（约 0.79×）。建议改用 `join` 的 lint 已移除。见 `evidence/_removed/nm-string-amp-in-loop.REMOVED.md`。
## IO

不要把 `echo` 放进热循环；门控或缓冲。
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| nm-seq-add-hot | 循环内 seq `.add` | off（G3） |
| nm-echo-hot | 循环内 `echo` | off（G3） |
| nm-seq-no-capacity | 空 seq + 有大小提示的 `.add` | hint |

## 另见

规则 ID：[rule-ids.md](rule-ids.md)。证据策略：[evidence-policy.md](evidence-policy.md)。流程门槛：根目录 [AGENT.md](../../../../zh-CN/AGENT.md)。
