# jp-hot-heavy-alloc — 待定措施

## 状态

**待处理措施** — 此机器上没有 `evidence/jp-hot-heavy-alloc.jsonl`。

## 原因

在 Android `onDraw` / 类似设备上热路径大量分配——需要 ART/设备 + 公平帧测试工具。

## 政策

默认严重性 **关闭**（使用 `--enable` 运行）。在未在正确运行时提供真实的前后情况之前，请勿将其升级为错误。
