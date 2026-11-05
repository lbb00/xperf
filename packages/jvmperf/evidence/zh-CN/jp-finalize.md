# jp-finalize — 待处理措施

## 状态

**待处理措施** — 此机器上没有 `evidence/jp-finalize.jsonl`。

## 原因

`finalize()` — 正确性 / GC 延迟气味；Shipilev 和 JDK 已弃用它。在进行公平的前/后速度微基准之前（Cleaner 是解决方法）。待作为实时时钟门控的测量。

## 政策

保持 **提示** / 复查。在没有在正确的运行时提供真实的前后对比之前，不要升级为错误。
