# lu-print-hot — 在循环中使用 `print`

## 主张

在 Lua 5.4 中，在热数值/`for` 循环中调用 `print(...)` 要比静默累加（或在之后只打印一次）慢得多，即使每个 `print` 都被重定向到 `/dev/null`。格式化和写入管道占据主导；在真实的 TTY/管道上通常更慢，而且**依赖环境**。

## 如何测量

- 测试工具: `packages/luaperf/examples/bench/evidence_lu003.lua`
- 计时器: Lua `os.clock()`（CPU 秒）
- 协议: 预热=3；取9轮的中位数；每次计时样本前执行 `collectgarbage("collect")`
- **标准输出目标:** 通过 `_G.print` 重载到 `/dev/null`（Lua 5.4 的 `print` 写入 C 的 `stdout` FILE*，所以单独 `io.stdout = …` 并不能重定向；测试工具替换了 `print`）
- 配对 A（对应测试用例 `bad/lu-print-hot_print_loop.lua` / `good/lu-print-hot_print_outside.lua`）：N=20000
  - **之前:** 每次迭代 `print(i)`
  - **之后:** 安静地 `s = s + i` 然后只 `print(s)` 一次
- 配对 B（先缓冲再一次写入）：N=20000
  - **之前:** 每次迭代 `print(i)`
  - **之后:** `parts[i] = tostring(i)` 然后只 `print(table.concat(parts, "\n"))` 一次
- 配对 C（小 N）: N=100
- 原始行: [`lu-print-hot.jsonl`](../lu-print-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海（机器时钟；JSONL `ts` 为 UTC） |
| Lua | **Lua 5.4.7** |
| 标准输出 | **`/dev/null`** (`_G.print` → `io.open("/dev/null","w")`) |
| 中值之前 (`print_in_loop`) | 7.507 毫秒 |
| (`quiet_then_print_once`) 之后的中位数 | 0.088 毫秒 |
| **打印/静音 比率** | **~85.3×** |
| 调用前中位数 (`print_in_loop_vs_buffer`) | 7.551 毫秒 |
| (`buffer_then_one_print`) 后的中位数 | 3.783 毫秒 |
| **打印/缓冲比** | **~2.0×** |
| 循环前的中位数 (`small_print_in_loop`) | 0.037 毫秒 |
| (`small_quiet_once`) 之后的中位数 | 0.001 毫秒 |
| **比率 小 N** | **~37×**（之后接近计时器底值 — 仅方向性） |

方向稳定：循环内 `print` 有成本；quiet/once 成本低。绝对毫秒数和比例会随接收端（null、pipe 或 TTY）、Lua 构建版本和 N 变化而波动。在 Lua 或机器更改后重新运行测试程序。

## 与 lint 的对应

`luaperf-lint` lu-print-hot 标记循环窗口内的 `print(`（不是像 `to_print` 这样的名字 — 参见 `good/lu-print-hot_to_print_name.lua`）。根据 [evidence-policy](../../docs/zh-CN/evidence-policy.md)，默认严重性保持为 **`hint`**：

- 即使使用 `/dev/null`，这台机器上的成本依然是**真实的**。
- 仍然不是一个 `错误` 门控（与 jsperf **JP002** / cperf **CP003** 的理由相同）：故意的调试循环、测试辅助工具和 CLI 进度打印是常见的；比率会随着接收端而大幅波动；仅通过缓冲在这里也只是~2倍。
- 将其视为针对热路径的审查提示；只有在路径已知为热点且打印是非故意时，才使用 `--severity lu-print-hot=error` 逐树升级。

## 限制

- 微基准测试；不是应用程序配置文件。
- 计时器是 `os.clock()`，在 Lua 级别的 `print` 覆盖下的 CPU 时间——低估了阻塞 TTY，可能与 C 语言 `stdout` 的 fwrite 成本不同。
- 不测量 `io.write`、自定义记录器或 ngx.log。
- 历史说明：lu-table-insert-hot 仍然“关闭”；在 G4 复查后，kit 后来改为**语料库准备就绪**（见 docs/corpus.md）。
