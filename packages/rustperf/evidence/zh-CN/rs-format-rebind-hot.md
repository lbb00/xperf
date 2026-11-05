# rs-format-rebind-hot — 在循环中重新绑定格式化累积

## 主张

在 Rust 中，使用热循环 `s = format!("{s}…")` / `s = format!("{}{}", s, …)` 累积字符串的速度明显比 `String::with_capacity` + `write!` / `push_str` 慢，因为每次 `format!` 都会分配一个新的 `String` 并复制不断增长的前缀（大约呈二次方增长）。

## 如何测量

与以前的 rs-string-plus-in-loop 格式相同的挂载和运行！配对（不是重新发明的）:

- 测试工具：`packages/rustperf/examples/bench/evidence_rs002.rs`（Pair C）
- 构建：`rustc -C opt-level=3 evidence_rs002.rs -o out/evidence_rs002`
- 计时器：`std::time::Instant` 墙钟时间；预热=3；取9次的中位数；`std::hint::black_box`
- Pair C（匹配测试用例 `rustperf-lint/fixtures/bad/rs-format-rebind-hot_format_rebind.rs` / 良好 `rs-format-rebind-hot_write.rs`）：N=20000
  - **之前：** 循环中 `s = format!("{s}{i}")`
  - **之后：** `with_capacity` + `write!(s, "{i}")`
- 原始数据行：[`rs-format-rebind-hot.jsonl`](../rs-format-rebind-hot.jsonl) — **来源别名** 自 2026-10-22 rs-string-plus-in-loop G4 JSONL（`rule` 字段设为 `rs-format-rebind-hot`; `aliased_from=rs-string-plus-in-loop`; `median_ms` / `ops` / `ts` 相同）

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海（机器时钟；JSONL `ts` 为 UTC） |
| rustc | **1.99.1** |
| 选项 | **优化级别=3** (`-C opt-level=3`) |
| 前中位数 (`digits_format_accum`) | 28.652 毫秒 |
| (`digits_write`) 之后的中位数 | 0.288 毫秒 |
| **比率格式！前/后** | **~100×** |

方向：`format!` 重新绑定累积对 **flagged** 异味是一个大而稳定的胜利。绝对毫秒数和比率取决于机器/优化。

## 与 lint 的对应

`rustperf-lint` **rs-format-rebind-hot** 仅在循环行包含 `ident = format!(…)`（**不是** `let ident = format!(…)`）且格式体/参数重用 `ident`（`{ident}` 或位置标记）时触发。裸露的 `format!(…)` 表达式和新的 let 绑定不会触发警告。根据 [evidence-policy](../../docs/zh-CN/evidence-policy.md)，默认严重性为 **`error`**：被标记的代码味道本身约为 99×。路径跳过镜像 `rs-string-plus-in-loop`（适用于 shell / 冷 CLI 格式化器）。摊销的 `+=` / `push_str` 保持在 **rs-string-plus-in-loop**（提示）。

## 限制

- 微型基准；不是应用程序配置文件。
- 行启发式仍可能触发一次性换行，这种换行在每次外部迭代中会重复使用左侧表达式（参见 G3 剩余注释）——如有需要，可使用 `--severity rs-format-rebind-hot=off` / `hint` 覆盖。
- 不测量 `Write` 特征对象、`itoa` 或 SSO。
- 历史说明：编写于 r4 重设计之前；现在该工具包已**适用于语料库**（参见 docs/corpus.md）。
