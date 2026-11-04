# jp-sleep-polling — 待定措施

## 状态

**待处理措施** — 此机器上没有 `evidence/jp-sleep-polling.jsonl`。

## 原因

`Thread.sleep` 轮询——挂钟时间主要由休眠本身占据；用 park/condition 替换是正确性/延迟的设计问题，而不是我们可以诚实地作为错误来限制的微小比例。

## 政策

默认严重性 **关闭**（使用 `--enable` 运行）。在没有在正确运行时进行真实的前后对比之前，不要升级为错误。
