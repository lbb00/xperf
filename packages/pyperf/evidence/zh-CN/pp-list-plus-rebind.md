# pp-list-plus-rebind — xs = xs + [i] 与 append

## 主张

在这台机器上测量：主要热用例 **`list_plus_rebind`** 比率前/后 **~1872.93×**（之后更快）。默认严重性保持 **`hint`**。仅凭这一填充 **不要** 升级为 `error`——比率很高，但策略/默认值和 G3 OK-idiom 历史保持严重性不变。

## 如何测量

- 测试工具：`packages/pyperf/examples/bench/evidence_pp.py`
- 协议：warm=3；9轮的中位数；在适用的地方执行GC/收集
- 原始数据行：[`pp-list-plus-rebind.jsonl`](../pp-list-plus-rebind.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海（机器时钟；JSONL 时间戳为 UTC） |
| Toolchain | **CPython 3.15.1** |
| 在 (`list_append`) 之后的中位数 | 0.302584 毫秒 (操作=20000，比率=1.000000) |
| `list_plus_rebind` 之前的中位数 | 566.717875 毫秒（操作数=20000，比例=1872.927988） |
| (`small_append`) 后的中位数 | 0.006208 毫秒 (操作=100，比例=1.000000) |
| 中位数之前 (`small_list_plus`) | 0.013167 毫秒 (操作次数=100，比率=2.120912) |
| **前后主要比率** | **~1872.93×** (`list_plus_rebind`) |

方向和绝对毫秒数对机器/工具链/选项敏感。在工具链或机器更改后，请重新运行测试套件。

## 与 lint 的对应

`pyperf-lint` **pp-list-plus-rebind** 默认保持 **`hint`**。推荐升级：**否（强烈的微基准测试，保持当前默认；升级需要政策候选 + 语料库一致性）**。

## 限制

- 微基准；不是应用程序性能概况。
- 小行数的测试结果可能接近计时器噪声；在进行比率声明时，优先使用热（非小）案例。
- I/O 规则（print/echo/puts/writeln）丢弃到 `/dev/null` — 依赖环境。
