# cp-printf-hot — 循环中的 printf / fprintf

## 权利要求（狭义）

当 `fprintf` 在强制无缓冲（`_IONBF`）的流上运行的**真正热的**路径时，墙钟时间比在该 Linux 机器上用大 `_IOFBF` 缓冲区在 `cc -O2` 下的**相同调用位置**慢好几倍。完全移除 I/O 则又快一个数量级。

## 我们*不*做的声明

仅仅出现 cp-printf-hot lint 并**不**意味着进程很慢：死掉的辅助程序、`#if 0` 代码块以及 dump/codegen 打印器会以约 **1.0×** 热路径时间触发扫描器（参见 STATIC-VS-O2 case3）。

## 如何测量

- 来源：`packages/cperf/examples/bench/cp003_printf_hot.c`
- 构建：`cc -std=c11 -O2 -o cp003_printf_hot cp003_printf_hot.c`
- 计时：`clock_gettime(CLOCK_MONOTONIC)`；预热=2；9轮的中位数；N=80000；输出 `/dev/null`
- **之前：** `setvbuf(_IONBF)` + 每次迭代 `fprintf`
- **之后：** `setvbuf` 1 MiB `_IOFBF` + 每次迭代相同 `fprintf` (+ `fflush`)
- **参考：** 仅计算的静默循环（上限）
- 原始数据行：[`cp-printf-hot.jsonl`](../cp-printf-hot.jsonl)
- 相关负值案例：`case3_dead_printf.c` / lint 探针 `case3_if0.c`（静态触发，无时间增量）

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| 编译器 | **cc (Debian 14.2.0-19) 14.2.0** · 参数 `cc -std=c11 -O2` |
| 调用前中位数 (`unbuffered_fprintf`) | ~14.05 毫秒 |
| (`buffered_fprintf`) 后的中位数 | ~2.94 毫秒 |
| **未缓冲/缓冲 前后比** | **~4.8×** |
| 静默参考 | ~0.025 毫秒 · unbuf/静默 ≈ **561×** |

Companion STATIC-VS-O2 case2 ≈ **3.8×** 未缓冲/缓冲；case3 死亡/`#if 0` ≈ **1.0×**。

## 与 lint 的对应

`cperf-lint` cp-printf-hot 会在循环体内检测 `printf`/`fprintf`/`puts`（及类似函数），同时考虑 dump/debug/`print*` / `#if DUMP|DEBUG|…` / 路径抑制。默认严重性为 **关闭**（G3 降级），根据 [evidence-policy](../../docs/zh-CN/evidence-policy.md)：对于 *高频* I/O 存在已测量的一致性，但“发现 ⇒ 成本”的相关性 **部分**（预处理器忽略 `#if 0`、dump 噪声）。仅当路径已知为热点时，可使用 `--severity cp-printf-hot=hint`（或 `error`）按树启用。

## 限制

- 扫描器不是预处理器；`#if 0` 仍然可能产生检测结果。
- 缓冲与非缓冲是一种修复方法；通常正确的修复方法是在性能关键路径上根本不打印。
- `/dev/null` 微基准低估了真实 tty/文件的成本；但仍足以表明在关键路径上这个问题很重要。
