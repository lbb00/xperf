# cp-realloc-grow-one — 按一增长的 realloc

## 主张

在这台 Linux 机器上，当增长发生在被测路径上时，每次推入时使用 `realloc(p, (len+1) * sizeof T)` 增长缓冲区，比在 `cc -O2` 下使用容量加倍要慢得多。

## 如何测量

- 来源：`packages/cperf/examples/bench/cp002_realloc_growth.c`
- 构建：`cc -std=c11 -O2 -o cp002_realloc_growth cp002_realloc_growth.c`
- 时间测量：`clock_gettime(CLOCK_MONOTONIC)`；预热=3；取9轮中位数；N=100000
- **之前：** 每次推入时使用 `realloc` 到 `len+1`
- **之后：** 当 `len+1 > cap` 时将容量翻倍
- 原始数据行：[`cp-realloc-grow-one.jsonl`](../cp-realloc-grow-one.jsonl)
- 配套文件：通过 `scripts/run-static-vs-o2.sh` 的 `examples/bench/case4_realloc_growth.c`

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| 编译器 | **cc (Debian 14.2.0-19) 14.2.0** · 参数 `cc -std=c11 -O2` |
| `realloc_plus_one` 之前的中位数 | ~0.63 毫秒 |
| `capacity_doubling` 后的中位数 | ~0.05 毫秒 |
| **前/后比例** | **~12.6×** |

伴随 STATIC-VS-O2 case4（同一天，中位数为 7）：嗅觉约 0.81 毫秒 → 清洁约 0.25 毫秒 ≈ **3.2×**。绝对比率因线束（时间窗口 / 预热）而异，但 **方向和与嗅觉的一致性是清楚的**。

## 与 lint 的对应

`cperf-lint` 会在尽力使用的 `realloc(..., …+1)` / `old+1` 样式第二个参数时触发。根据 [evidence-policy](../../docs/zh-CN/evidence-policy.md)，严重性为 **错误** —— 当该模式热时，JSONL 存在并且实际时间一致。

## 限制

- 在成熟的树上很少见（语料本身几乎从未出现）。
- 对于已知最终大小的合法一次性 `realloc(p, n+1)` 并不是问题；lint 是根据第二个参数的形式进行启发式检查的。
- 不模拟自定义分配器或使用不同因子的摊销增长。
