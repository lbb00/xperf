# rs-collect-vec-hot — 在循环中使用 collect::<Vec<_>> 与 .count()

## 主张

在这台机器上测量：主要热案例 **`collect_in_loop`** 比例前/后 **~2.14×**（之后更快）。默认严重性保持 **`hint`**。仅凭此填充 **不要** 升级为 `error`。

## 如何测量

- 测试框架：`packages/rustperf/examples/bench/evidence_rs003_rs005_rs006.rs`
- 协议：warm=3；取9轮的中位数
- 优化：`opt-level=3`
- 原始行：[`rs-collect-vec-hot.jsonl`](../rs-collect-vec-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海（机器时钟；JSONL 时间戳是 UTC） |
| Toolchain | **1.85.1** |
| 选项 | **优化级别=3** |
| (`count_no_collect`) 之后的中位数 | 0.333875 毫秒 (操作数=5000，比例=1.000000) |
| 循环中收集前的中位数 (`collect_in_loop`) | 0.714542 毫秒 (操作次数=5000，比例=2.140148) |
| (`small_count`) 后的中位数 | 7.044250 毫秒 (操作=50，比例=1.000000) |
| `small_collect` 之前的中位数 | 13.768250 毫秒 (操作次数=50，比率=1.954537) |
| **主要比率 前/后** | **~2.14×** (`collect_in_loop`) |

方向和绝对毫秒数对机器/光学敏感。在工具链或机器更改后，请重新运行测试夹具。

## 与 lint 的对应

`rustperf-lint` **rs-collect-vec-hot** 默认保持 **`hint`**。建议升级：**否**。

## 限制

- 微基准；不是应用程序性能概况。
- 小行数的测试结果可能接近计时器噪声；在进行比率声明时，最好使用热点（非小规模）案例。
- I/O 规则（print/echo/puts/writeln）丢弃到 `/dev/null`——依赖环境。
