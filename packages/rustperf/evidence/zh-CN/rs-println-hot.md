# rs-println-hot — 每次迭代使用 writeln/println 与缓冲区比较然后写入

## 主张

在每次循环迭代中向 `/dev/null` 写一行，比将内容缓冲到 `String` 中的 `writeln!` 然后一次性 `write_all` 慢 **约 64.9 倍**（rustc 1.99.1 `-C opt-level=3`，本机测试）。与一个安静的计算循环相比，这个差距非常大（受 I/O 限制）——该示例仅用于参考，**不得**因此提高设置。默认仍为 **`hint`**（取决于环境/I/O）。

## 如何测量

- 测试框架: `packages/rustperf/examples/bench/evidence_rs003_rs005_rs006.rs`
- 构建: `rustc -C opt-level=3`
- 计时器: `std::time::Instant`; 预热=3; 取9次的中位数; `black_box`
- 组合 A: N=20000
  - **之前:** 每次迭代 `writeln!(null, "{i}")`
  - **之后:** 缓冲行然后一次性写入 `/dev/null`
- 组合 B (上下文): 同样的之前 vs 安静算术 (无 I/O)
- 原始行: [`rs-println-hot.jsonl`](../rs-println-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海（机器时钟；JSONL `ts` 为 UTC） |
| rustc | **1.99.1** |
| 选项 | **优化级别=3** |
| `writeln_each_iter` 之前的中位数 | 6.582 毫秒 |
| (`buffer_then_write`) 后的中位数 | 0.524 毫秒 |
| **比率缓冲对** | **~64.85×** |
| (`quiet_compute`) 后的中位数 | ~0.00005 毫秒 |
| writeln 与 quiet 的比率 | 巨大（有 I/O 与无 I/O — 不升级基础） |

## 与 lint 的对应

`rustperf-lint` **rs-println-hot** 默认保持 **`hint`**。建议升级：**否**（依赖 I/O 环境，与 lu-print-hot 和 cp-printf-hot 属于同一类）。

## 限制

- 微基准测试；标准输出被丢弃到 `/dev/null`。
- 实际 TTY/标准错误竞争可能会显著改变绝对毫秒数。
- 不会单独测量 `println!` 宏格式化与写入系统调用。
