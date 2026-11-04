## 3. 测量

说短一点、诚实一点：本 kit 不替代 `perf`。用下面工具判断某次 cperf-lint 命中是否要紧。

### 3.1 墙钟与计数器

```sh
perf stat -e cycles,instructions,cache-misses,branch-misses,task-clock -- ./app
perf stat -e cycles,instructions,cache-misses,branch-misses,task-clock -- ./app
perf record -g -- ./app && perf report   # 尽量保留 frame pointers
perf record -g -- ./app && perf report   # 尽量保留 frame pointers
```

记录编译器（`cc -v`）、标志（`-O2` / `-O3` / `-flto`）、OS 与 CPU 型号。比较分布（N 次最优或中位数），不要只看一个样本。

### 3.2 Cachegrind / callgrind

`valgrind --tool=cachegrind ./app` 模拟缓存行为；没有 PMC 时有用。慢；不宜作为大树的 CI 门禁。

### 3.3 Sanitizer 不是测速工具

ASan / TSan / UBSan 找 bug。它们会放大时间与 RSS。在改动分配器或竞态的同一变更集上用它们；数字只引用**未开 sanitizer** 的 Release 构建。

### 3.4 实测门禁 vs dogfood

树内 `evidence/` 下的 JSONL（见 [evidence-policy.md](evidence-policy.md)）：

| 规则 | 严重级别 | 墙钟（本地运行） |
|------|----------|------------------|
| cp-alloc-hot | **error** | 循环 malloc 对比 arena 约 10.8× |
| cp-realloc-grow-one | **error** | realloc(+1) 对比倍增约 12.6× |
| cp-printf-hot | **off**（默认） | 热路径无缓冲/缓冲约 4.8×；`#if 0` 约 1.0× → 部分 |
| cp-strlen-in-cond | **hint** | 字符串可变时约 125×；能提升时约 1× |
| cp-strcat-hot | **off**（默认） | 约 221×；保持 off |
| cp-sprintf-hot | **hint** | 有 JSONL；保持 hint；未做语料 triage |
| cp-fopen-hot | **hint** | 有 JSONL；保持 hint；未做语料 triage |
| cp-gettime-hot | **hint** | 有 JSONL；保持 hint；未做语料 triage |
| cp-wide-bool-flags | **hint** | 有 JSONL；保持 hint；未做语料 triage |
| cp-regex-hot | **hint** | JSONL 约 9.7×；未做语料 triage |
| cp-alloca-hot | **hint** | 栈 1280000 vs 64 字节；墙钟约 1×；未做语料 triage |
| cp-struct-by-value | **hint** | JSONL 跨 TU 约 12.3×；同 TU 约 1×；未做语料 triage |

语料残留计数（§2.3）仍只是 lint dogfood。模式演示（`examples/m01_arena.c`）仍说明 API，不替代 JSONL 门禁。
