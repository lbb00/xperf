# nimperf 证据政策

## 门槛

一条规则只有在同时存在 `evidence/<RULE>.md` 和测量的 `evidence/<RULE>.jsonl` 时才可以是 **`error`**。

## 当前映射

截至2026年10月22日。

| 规则 | 严重性 | 证据 | 异味 |
|------|----------|----------|-------|
| nm-seq-add-hot | **关闭** | Nim 2.2.12 ~**8.97×** | 循环中的 seq `.add`（G3 OK-惯用法） |
| nm-echo-hot | **关闭** | Nim 2.2.12 ~**1670×**（在 0.003 毫秒后）| 循环中的 `echo`（G3 CLI）|
| nm-seq-no-capacity | 提示 | Nim 2.2.12 ~**1.42×** | 在有大小提示的循环中对空序列使用 `.add` |

没有测量的 JSONL — nm-seq-no-capacity 保持 **提示**。`nm-string-amp-in-loop` 已被移除：在 Nim 2.2.12 上 `join` 比 `&=` 慢（大约 0.79 倍，之前的一次运行大约 0.69 倍）。见 `evidence/_removed/`。
