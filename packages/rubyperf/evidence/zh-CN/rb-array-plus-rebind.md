# rb-array-plus-rebind — a = a + [x] 与 <<

## 主张

在这台机器上测量：主要热案例 **`array_plus_rebind`** 的前/后比约为 **~131.34×**（之后更快）。默认严重性保持 **`off`**。仅凭这一优化不要升级为 `error` — 比例虽然很高，但策略/默认设置以及 G3 OK-idiom 历史保持严重性不变。

## 如何测量

- 测试套件：`packages/rubyperf/examples/bench/evidence_rb.rb`
- 协议：warm=3；9轮的中位数；在适用的情况下进行GC/收集
- 原始文件：[`rb-array-plus-rebind.jsonl`](../rb-array-plus-rebind.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海（机器时钟；JSONL 时间戳为 UTC） |
| Toolchain | **Ruby 4.0.8** |
| 使用 (`shovel`) 后的中位数 | 0.441000 毫秒 (操作=20000，比率=1.000000) |
| `array_plus_rebind` 之前的中位数 | 57.921000 毫秒 (操作次数=20000, 比率=131.340176) |
| (`small_shovel`) 后的中位数 | 0.003000 毫秒 (操作=100，比率=1.000000) |
| 中位数之前 (`small_array_plus`) | 0.005000 毫秒 (操作=100, 比率=1.666615) |
| **主要比率 前/后** | **~131.34×** (`array_plus_rebind`) |

方向和绝对毫秒数对机器/工具链/选项敏感。在工具链或机器更改后，请重新运行测试套件。

## 与 lint 的对应

`rubyperf-lint` **rb-array-plus-rebind** 默认保持 **`off`**。建议升级：**否**。

## 限制

- 微基准；不是应用程序性能分析。
- 小样本行数可能接近计时器噪声；对于比例声明，建议使用热（非小）案例。
- I/O 规则（print/echo/puts/writeln）会丢弃到 `/dev/null` — 取决于环境。
