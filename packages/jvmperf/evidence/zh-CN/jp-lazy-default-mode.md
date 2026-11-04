# jp-lazy-default-mode — 待定措施

## 状态

**待处理措施** — 此机器上没有 `evidence/jp-lazy-default-mode.jsonl`。

## 原因

Kotlin `by lazy` 默认模式（SYNCHRONIZED）是情境性的——仅在争用或初始化成本被分析时测量。没有能概括的准确微基准；保持挂起状态。

## 政策

默认严重性 **关闭**（使用 `--enable` 运行）。在没有在正确运行时进行真实的前后对比之前，不要升级为错误。
