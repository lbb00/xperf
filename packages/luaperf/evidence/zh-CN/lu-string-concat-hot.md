# lu-string-concat-hot — 循环中使用 `..` 进行字符串累加

## 主张

在 Lua 5.4 中，在数值/`for` 循环中用 `s = s .. chunk` 来构建字符串比先收集各个部分然后使用 `table.concat` 要慢得多，因为每次使用 `..` 都会复制不断增长的前缀（经典的二次成本）。随着 N 和 chunk 大小增加，开销会增大；对于很小的 N，开销大约是 1×。

## 如何测量

- 测试工具：`packages/luaperf/examples/bench/evidence_lu002.lua`
- 计时器：Lua `os.clock()`（CPU 秒；单线程内核 ≈ 该机器上的实际时间）
- 协议：预热=3；9轮取中位数；每次计时样本前执行 `collectgarbage("collect")`
- 配对 A（匹配测试夹具 `bad/lu-string-concat-hot_concat_loop.lua` / `good/lu-string-concat-hot_concat.lua`）：N=20000
  - **之前：** 循环中 `s = s .. tostring(i)`
  - **之后：** `parts[i] = tostring(i)` 然后 `table.concat(parts)`
- 配对 B（固定 32 字节块）：N=10000
  - **之前：** 循环中 `s = s .. chunk`
  - **之后：** 索引填充 parts 然后 `table.concat`
- 配对 C（小 N 一次性）：N=100 — 预期 ~1×
- 原始行：[`lu-string-concat-hot.jsonl`](../lu-string-concat-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海（机器时钟；JSONL `ts` 为 UTC） |
| Lua | **Lua 5.4.7** |
| 中位数之前 (`digits_concat_loop`) | 54.149 毫秒 |
| (`digits_table_concat`) 后的中位数 | 8.248 毫秒 |
| **前后数字比例** | **~6.57×** |
| `chunk32_concat_loop` 之前的中位数 | 60.630 毫秒 |
| (`chunk32_table_concat`) 之后的中位数 | 0.518 毫秒 |
| **ratio chunk32 前/后** | **~117×** |
| 前中值（`small_n_concat_loop`） | 0.032 毫秒 |
| (`small_n_table_concat`) 之后的中位数 | 0.033 毫秒 |
| **ratio small N** | **~0.97×** (~1×) |

各对之间方向稳定；绝对毫秒和比率对 N/块/机器敏感（呈二次关系）。在 Lua 或机器更改后重新运行测试工具。

## 与 lint 的对应

`luaperf-lint` lu-string-concat-hot 标记在循环窗口内进行字符串累加 `s = s .. x`（不是一次性构建的键值，如 `k .. "=" .. v` — 参见 `good/lu-string-concat-hot_oneshot_key.lua`）。根据 [evidence-policy](../../docs/zh-CN/evidence-policy.md) 的默认严重性是 **`error`**：该 JSONL 存在，wall/CPU 同意这是热累加，并且 G3 语料库的残差（例如 APISIX http-dubbo）看起来像真实的 TP。较小/冷的循环可能仍然没问题 — 当循环不频繁时，可以使用 `--severity lu-string-concat-hot=hint` 或 `off` 来覆盖。

## 限制

- 微型基准测试；不是应用程序配置文件。
- 计时器是 `os.clock()` CPU 时间，而不是 `CLOCK_MONOTONIC`；对于单线程 CPU 密集型字符串操作可以，但不适用于 I/O 密集型路径。
- Pair C 显示在极小的 N 下，这种现象是情境性的——不要把每个 `..` 都当作崩溃错误。
- 不测量 `__concat` 元方法或用户数据。
- 历史备注：lu-table-insert-hot 仍然是关闭状态；kit 后来在 G4 重新检查后切换为 **语料库就绪**（见 docs/corpus.md）。
