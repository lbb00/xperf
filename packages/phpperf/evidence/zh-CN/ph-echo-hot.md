# ph-echo-hot — 每次迭代使用 echo/fwrite 与 一次性使用 implode

## 主张

在这台机器上测量：主要热案例 **`echo_each_iter`** 比率前/后 **~21.31×**（之后更快）。默认严重性保持 **`hint`**。仅凭此填充 **不要** 升级为 `error`。

## 如何测量

- 测试套件：`packages/phpperf/examples/bench/evidence_ph001_ph003.php`
- 协议：预热=3；9轮的中位数；在适用时进行垃圾回收/收集
- 原始数据行：[`ph-echo-hot.jsonl`](../ph-echo-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海（机器时钟；JSONL 时间戳为 UTC） |
| Toolchain | **PHP 8.5.12** |
| 在 (`implode_once`) 之后的中位数 | 0.575792 毫秒 (操作=20000，比率=1.000000) |
| 中位数之前 (`echo_each_iter`) | 12.272208 毫秒 (操作=20000，比率=21.313613) |
| **主要比率 前/后** | **~21.31×** (`echo_each_iter`) |

方向和绝对毫秒数对机器/工具链/选项敏感。在工具链或机器更改后，请重新运行测试程序。

## 与 lint 的对应

`phpperf-lint` **ph-echo-hot** 默认保持 **`hint`**。推荐升级：**否**。

## 限制

- 微基准；不是应用程序性能分析。
- 小样本行数可能接近计时器噪声；对于比例声明，建议使用热（非小）案例。
- I/O 规则（print/echo/puts/writeln）会丢弃到 `/dev/null` — 取决于环境。
