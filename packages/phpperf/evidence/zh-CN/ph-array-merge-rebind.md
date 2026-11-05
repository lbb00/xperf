# ph-array-merge-rebind — 循环中 `$a = array_merge($a, …)` 的重新绑定

## 主张

在循环中使用 `$a = array_merge($a, $chunk)` 重新绑定累加器比使用 `$a[] = …`（或 `array_push`）追加要慢得多，在 PHP 8.4 中尤为明显，因为每次 `array_merge` 都会分配并复制不断增长的前缀（经典的二次成本）。成本随着 N 和块大小增长；即使 N≈100，在这台机器上仍然显示出明显差距。

## 如何测量

- 测试工具：`packages/phpperf/examples/bench/evidence_ph002.php`
- 计时器：PHP `hrtime(true)` 墙时纳秒
- 协议：预热=3；取9轮的中位数；每个计时样本前执行 `gc_collect_cycles()`
- A 对（对应测试用例 `bad/ph-array-merge-rebind_array_merge.php` / `good/ph-array-merge-rebind_push.php`）：N=20000
  - **之前：** 循环中 `$a = array_merge($a, [$i])`
  - **之后：** 循环中 `$a[] = $i`
- B 对（固定 8 元素块）：N=5000
  - **之前：** 循环中 `$a = array_merge($a, $chunk)`
  - **之后：** 循环中 foreach 推入 `$a`
- C 对（小 N）：N=100 — 仍然多倍；绝对毫秒很小
- 原始数据行：[`ph-array-merge-rebind.jsonl`](../ph-array-merge-rebind.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-23 亚洲/上海（机器时钟；JSONL `ts` 为 UTC） |
| PHP | **PHP 8.5.12** |
| 中位数之前 (`scalar_array_merge`) | 243.229 毫秒 |
| (`scalar_push`) 之后的中位数 | 0.234 毫秒 |
| **比率标量 前/后** | **~1038×** |
| `chunk8_array_merge` 之前的中位数 | 153.429 毫秒 |
| (`chunk8_push`) 后的中位数 | 0.267 毫秒 |
| **ratio chunk8 前/后** | **~574×** |
| `small_n_array_merge` 之前的中位数 | 0.019 毫秒 |
| (`small_n_push`) 后的中位数 | 0.001 毫秒 |
| **ratio small N** | **~12.8×** |

各对之间方向稳定；绝对毫秒和比率对 N/块/机器敏感（呈二次关系）。在 PHP 或机器更改后重新运行测试工具。

## 与 lint 的对应

`phpperf-lint` ph-array-merge-rebind 标记在循环窗口内同一变量的增长性重绑定 `$a = array_merge($a, …)`（而不是循环外的一次性合并 —— 参见 `good/ph-array-merge-rebind_oneshot_merge.php`）。在 [evidence-policy](../../docs/zh-CN/evidence-policy.md) 下，默认严重性为 **`error`**：此 JSONL 存在，wall 同意热累积的情况，并且 G3 语料库残留（Composer/Laravel）看起来是可靠的真实正例。冷/小型构建器仍然可以使用 —— 当循环不热时，可用 `--severity ph-array-merge-rebind=hint` 或 `off` 覆盖。

## 限制

- 微基准；不是应用程序配置文件。
- 不测量 `array_merge` 的 *key* 覆盖/关联重映射（规则目标是增长列表重绑定）。
- C 对的绝对时间接近计时器噪声；比率仍然有利于 push。
- 历史注：ph-string-dot-hot 后来把 `off` 降级；工具包在 G4 复查后翻转为 **语料库就绪**（见 docs/corpus.md）。
