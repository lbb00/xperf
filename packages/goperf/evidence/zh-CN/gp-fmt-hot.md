# gp-fmt-hot — 循环中的 fmt.Sprintf 与 strconv/Builder

## 主张

在这台机器上测得：主要热用例 **`fmt_sprintf_vs_itoa`** 的前/后比约为 **~2.81×**（之后更快）。默认严重性保持 **`off`**。仅凭这一填充 **不要** 升级为 `error`。

## 如何测量

- 测试工具：`packages/goperf/examples/bench/evidence_gp.go`
- 协议：预热=3；9轮的中位数；在适用的地方进行垃圾收集/收集
- 原始文件：[`gp-fmt-hot.jsonl`](../gp-fmt-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海（机器时钟；JSONL 时间戳为 UTC） |
| Toolchain | **go1.27.3** |
| 使用 (`strconv_builder`) 后的中位数 | 5.100292 毫秒 (操作=100000，比率=1.000000) |
| `fmt_sprintf_loop` 之前的中位数 | 6.008417 毫秒 (操作=100000, 比率=1.178054) |
| `strconv_itoa_only` 之后的中位数 | 2.137083 毫秒 (操作次数=100000, 比率=1.000000) |
| `fmt_sprintf_vs_itoa` 之前的中位数 | 6.008417 毫秒 (操作次数=100000, 比例=2.811504) |
| **主要比率 前/后** | **~2.81×** (`fmt_sprintf_vs_itoa`) |

方向和绝对毫秒数对机器/工具/选项敏感。在工具链或机器更改后，请重新运行测试工具。

## 与 lint 的对应

`goperf-lint` **gp-fmt-hot** 默认保持 **`off`**。建议升级：**否**。

## 限制

- 微基准；不是应用程序配置文件。
- 小 N 行可能接近计时器噪声；对于比率声明，建议使用热（非小）情况。
- I/O 规则（print/echo/puts/writeln）丢弃到 `/dev/null` — 取决于环境。
