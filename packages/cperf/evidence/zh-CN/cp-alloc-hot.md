# cp-alloc-hot — 循环体中的分配

## 主张

在这台 Linux 机器上使用 `cc -O2` 时，在紧密循环的每次迭代中调用 `malloc`/`free` 要比从预先分配好的内存池中为相同数量的 N 个小对象分配内存慢得多。

## 如何测量

- 来源：`packages/cperf/examples/bench/cp001_malloc_vs_arena.c`
- 构建：`cc -std=c11 -O2 -o cp001_malloc_vs_arena cp001_malloc_vs_arena.c`
- 计时：`clock_gettime(CLOCK_MONOTONIC)`；预热=3；取9轮的中位数；N=200000
- **之前：** 每次迭代 `malloc(sizeof(int))` + 写入 + `free`
- **之后：** 为 N 个整数分配一次 arena；每次迭代使用 bump 分配；只释放一次 arena
- 原始行：[`cp-alloc-hot.jsonl`](../cp-alloc-hot.jsonl)
- 配套：`scripts/run-static-vs-o2.sh` case1（相同模式；比率随测试环境配置变化）

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-21 亚洲/上海 (JSONL `ts` 为 UTC) |
| 编译器 | **cc (Debian 14.2.0-19) 14.2.0** · 参数 `cc -std=c11 -O2` |
| `malloc_free_in_loop` 之前的中位数 | 约 1.34 毫秒 |
| (`arena_bump`) 后的中位数 | ~0.12 毫秒 |
| **前后比例** | **~10.8×** |

重新测量 2026-10-21 19:19 亚洲/上海：前一个闸值约为 ~10.0×（1.44 → 0.14 毫秒）。漂移不显著；声明保持不变。

## 与 lint 的对应

`cperf-lint` 的 cp-alloc-hot 会在 `for`/`while`/`do` 循环体内对 `malloc`/`calloc`/`realloc` 触发（根据花括号深度启发式判断；薄 `return realloc(...)` 包装将被跳过）。根据 [evidence-policy](../../docs/zh-CN/evidence-policy.md)，严重性为 **错误**，因为该 JSONL 文件存在且一致。

## 限制

- 微型基准测试用于微小固定大小的分配；真实的热点路径可能需要使用内存池、栈缓冲区或提升复用——arena 是一种有效的解决方案，但不是唯一的。
- 对于已知 N 的初始化循环，每次分配一次且生命周期较长，通常是可以的；当循环不是热点时，把 lint 视为代码审核提示。
- 不衡量碎片化或多线程分配器的情况。
