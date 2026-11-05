# jp-console-hot — `console.*`

## 主张

在热循环中调用 `console.log`（以及相关方法）比在安静循环中慢得多，即使标准输出被丢弃——格式化和控制台管道是主要因素。真实的 TTY / 管道通常更慢，并且**依赖环境**。

## 如何测量

- 测试工具：`packages/jsperf/examples/bench/evidence_jp001_jp002.js`
- N_CONSOLE=20000；热身=3；9 次的中位数
- **之前：** 每次迭代 `console.log(i)` （stdout `write` 重定向到丢弃的 `Writable`）
- **之后（安静）：** 相同的算术操作，没有控制台输出
- **之后（一次）：** 安静循环 + 循环后一次 `console.log("done", s)`
- 原始数据行：[`jp-console-hot.jsonl`](../jp-console-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 |
| Node | **v20.19.2** |
| V8 | **11.3.244.8-node.38** |
| 循环中 `console_log_in_loop` 之前的中位数 | ~27.2 毫秒 |
| (`quiet_loop`) 之后的中位数 | ~0.021 毫秒 |
| **比率 控制台/安静** | **~1328×** |
| 中位数 `console_once_after` | ~0.11 毫秒 (~安静5倍；与循环内相比仍然很小) |

## 与 lint 的对应

jp-console-hot 标志 `console.*`（默认 `--scope all` 包含循环外的网站；`--scope loop` 保持原来的仅循环内匹配）。严重性在 [evidence-policy](../../docs/zh-CN/evidence-policy.md) 下保持 **`hint`** (`engine`) / **`off`** (`app`)：

- 即使没有 TTY，这台机器的成本也是**真实的**。
- 仍然不是一个 `错误` 门：有意的调试循环、测试辅助工具和 CLI 进度打印是常见的；比例随着接收端（丢弃 vs 管道 vs TTY）和日志库而变化。
- 将其视为对极端堆栈的审查提示（即使在非热点路径上，成本也会累积），而不是应用预设下“必须修复以提高速度”的 CI 失败。

## 限制

- 丢弃接收器低估了 TTY 的成本；没有夸大“日志记录是免费的吗？”——它不是免费的。
- 不测量 `pino` / 结构化记录器（通常更便宜，但在紧密循环中仍然不是免费的）。
- 不是形状/JIT 的异味；与 jp-alloc-hot/jp-delete-shape/jp-delete-array-hole 无关。
