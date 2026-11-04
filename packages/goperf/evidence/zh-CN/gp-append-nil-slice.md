# gp-append-nil-slice — 在 nil 切片上使用 append 与 make(...,0,len)

## 主张

在这台机器上的测量：主要热案例 **`append_grow`** 比率前/后约 **~7.28×**（之后更快）。默认严重性保持 **`hint`**。仅凭这一填充不要升级为 `error` —— 比率虽高，但策略/默认设置和 G3 OK-惯用历史保持严重性不变。

## 如何测量

- 测试工具: `packages/goperf/examples/bench/evidence_gp.go`
- 协议: warm=3; 取9轮的中位数; 如适用，GC/收集
- 原始行: [`gp-append-nil-slice.jsonl`](../gp-append-nil-slice.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海（机器时钟；JSONL 时间戳为 UTC） |
| Toolchain | **go1.27.3** |
| (`presize_make`) 之后的中位数 | 0.336292 毫秒 (操作次数=500000，比例=1.000000) |
| 之前的中值（`append_grow`）| 2.448459 毫秒（操作=500000，比例=7.280753）|
| 中位数（`small_presize`之后） | 0.000167 毫秒（操作=100，比率=1.000000） |
| 之前的中值 (`small_append_grow`) | 0.000166 毫秒 (操作次数=100，比例=0.994012) |
| **主要比率 前/后** | **~7.28×** (`append_grow`) |

方向和绝对毫秒数对机器/工具链/选项敏感。在工具链或机器更改后，请重新运行测试环境。

## 与 lint 的对应

`goperf-lint` **gp-append-nil-slice** 默认保持 **`hint`**。推荐升级：**否**。

## 限制

- 微基准；不是应用程序配置文件。
- 小 N 行可能接近计时器噪声；对于比率声明，建议使用热（非小）情况。
- I/O 规则（print/echo/puts/writeln）丢弃到 `/dev/null` — 取决于环境。
