# gp-string-plus-hot — string += 与 strings.Builder

## 主张

在这台机器上的测量：主要热案例 **`string_plus`** 比例前/后约 **~1481.22×**（之后更快）。默认严重性保持 **`off`**。仅凭这一填充不要升级为 `error` —— 比例虽高，但策略/默认设置及 G3 OK-idiom 历史保持严重性不变。

## 如何测量

- 测试工具：`packages/goperf/examples/bench/evidence_gp.go`
- 协议：warm=3；9轮的中位数；适用时进行GC/收集
- 原始数据行：[`gp-string-plus-hot.jsonl`](../gp-string-plus-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海（机器时钟；JSONL 时间戳为 UTC） |
| Toolchain | **go1.27.3** |
| 使用 (`strings_builder`) 后的中位数 | 0.217000 毫秒 (操作=50000，比率=1.000000) |
| 中位数之前 (`string_plus`) | 321.424750 毫秒 (操作=50000, 比例=1481.220046) |
| (`small_builder`) 之后的中位数 | 0.000334 毫秒 (操作次数=100，比率=1.000000) |
| 中位数之前 (`small_string_plus`) | 0.001667 毫秒 (操作次数=100，比率=4.991018) |
| **主要比例 前/后** | **~1481.22×** (`string_plus`) |

方向和绝对毫秒数对机器/工具链/选项敏感。在工具链或机器更改后，请重新运行测试套件。

## 与 lint 的对应

`goperf-lint` **gp-string-plus-hot** 默认保持 **`off`**。建议升级：**否**。

## 限制

- 微基准；不是应用程序性能分析。
- 小样本行数可能接近计时器噪声；对于比例声明，建议使用热（非小）案例。
- I/O 规则（print/echo/puts/writeln）会丢弃到 `/dev/null` — 取决于环境。
