# pp-print-hot — 循环打印 vs 仅 join 一次（标准输出被丢弃）

## 主张

在这台机器上测量：主要热案例 **`print_in_loop`** 比例前/后 **~2.10×**（之后更快）。默认严重性保持 **`off`**。仅凭此填充不要升级为 `error`。

## 如何测量

- 测试工具: `packages/pyperf/examples/bench/evidence_pp.py`
- 协议: warm=3; 9轮的中位数; 在适用的地方进行GC/收集
- 原始数据行: [`pp-print-hot.jsonl`](../pp-print-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海（机器时钟；JSONL 时间戳为 UTC） |
| Toolchain | **CPython 3.15.1** |
| (`print_join_once`) 之后的中位数 | 1.073375 毫秒 (操作次数=20000，比例=1.000000) |
| 之前的中值（`print_in_loop`） | 2.258042 毫秒（操作=20000，比例=2.103684） |
| **主要比率 前/后** | **~2.10×** (`print_in_loop`) |

方向和绝对毫秒数对机器/工具链/选项敏感。在工具链或机器更改后，请重新运行测试环境。

## 与 lint 的对应

`pyperf-lint` **pp-print-hot** 默认保持 **`关闭`**。推荐升级：**否**。

## 限制

- 微基准；不是应用程序性能概况。
- 小行数的测试结果可能接近计时器噪声；在进行比率声明时，最好使用热点（非小规模）案例。
- I/O 规则（print/echo/puts/writeln）丢弃到 `/dev/null` — 依赖环境。
