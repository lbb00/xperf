## 1. 分配

### 1.1 热路径 `malloc` / `calloc`

紧循环里的 `malloc` / `free` 会付分配器开销、可能碎片化，并给每次迭代加上失败路径。优先：

| 模式 | 何时 |
|------|------|
| **Arena**（bump 指针；一次性释放 / 重置） | 同一生命周期：请求、帧、解析、批次 |
| **按尺寸分级的池** | 大量等长对象；检出 / 归还 |
| **栈 / VLA / 固定缓冲** | 上界已知且小；生命周期嵌在调用方内 |
| **提到循环外** | 跨迭代复用同一缓冲 |

见 `examples/m01_arena.c`。

Lint：**cp-alloc-hot** —— `for` / `while` / `do` 体内的 `malloc` / `calloc` / `realloc`（花括号深度启发式）。

**实测证据（error 档）：** [`evidence/cp-alloc-hot.md`](../../evidence/zh-CN/cp-alloc-hot.md) · [`cp-alloc-hot.jsonl`](../../evidence/cp-alloc-hot.jsonl) —— `cc -std=c11 -O2`（Debian gcc 14.2.0），每轮 malloc+free 对比 arena bump 约 **10.8×**（N=2e5，9 次中位数）。策略：[evidence-policy.md](evidence-policy.md)。Harness：`examples/bench/cp001_malloc_vs_arena.c`。

证据（语料命中，非墙钟）： 在成熟 VM 上，跳过后真正的热路径「循环 malloc」很少。r2 包装 / 花括号修复后：quickjs cp-alloc-hot **0**；lua cp-alloc-hot **0**。剩余压力主要在紧凑树与胶水：sqlite `src/` r3 **14**（如 `tclsqlite.c` 行循环里 realloc）；gcc 稀疏 r3 **28**。单行 `return realloc(...)` 包装在 r1 是误报（r2 已清）。把 cp-alloc-hot 命中当作评审提示——按已知 N 只分配一次的初始化循环往往没问题。

### 1.2 无容量的增长（cp-realloc-grow-one）

反复 `realloc(p, n + 1)`（或 `old + 1`）是平方级并会搬缓冲。分开跟踪 `len` 与 `cap`；按倍增（或其他固定因子）增长。

Lint：**cp-realloc-grow-one** —— 对 grow-by-one 的尽力正则。

**实测证据（error 档）：** [`evidence/cp-realloc-grow-one.md`](../../evidence/zh-CN/cp-realloc-grow-one.md) · [`cp-realloc-grow-one.jsonl`](../../evidence/cp-realloc-grow-one.jsonl) —— realloc(+1) 对比容量倍增约 **12.6×**（N=1e5）；配套 STATIC-VS-O2 case4 约 **3×**。严重级别 error。

证据（语料命中）： 在引擎语料上几乎从不开火——quickjs / lua **0**；gcc 稀疏 **1**；sqlite **1**（r3）。成熟代码里该模式少见；实测门禁仍会让绿地增长在 `--preset app` 下失败。

### 1.3 语料教给我们的噪声

| 噪声类 | 示例 | cperf-lint 中的应对 |
|--------|------|---------------------|
| 生成 / harness | `unicode_gen.c`、`fuzz/`、`run-test262.c`、`ltests.c` | 路径跳过 |
| 薄分配器包装 | `return realloc(p, n);` | 跳过单语句包装（r2） |
| 无花括号 `for` 粘上下一句 | 单行循环后接包装 | 清除 `pending_loop`（r2） |

路径跳过还覆盖 gcc `testsuite/`、`gen*.c/cc`、`*generate*`、`generated/`、`*dump*` 源。完整清单：[corpus.md](corpus.md)。

### 1.4 暂定

无界 freelist / 缓存引起的 RSS 尖峰需要工作集上限——树内尚未测。SoA vs AoS：`examples/p01_soa.c`（布局演示，无计时声明）。

### 1.5 循环条件里的 `strlen`（cp-strlen-in-cond）

`for (i = 0; i < strlen(s); i++)` 每次迭代重算长度（常为 O(n²)）。提升 `size_t n = strlen(s)`（或用已知长度）。Lint：**cp-strlen-in-cond** —— 默认 hint。编译器必须重算时约 125×；`-O2` 能提升时约 1×。

### 1.6 循环里的 `strcat`（cp-strcat-hot）

反复 `strcat`/`strncat` 每次从起点扫目标。优先用尾指针 + `memcpy`，或可用时用 `stpcpy`。Lint：**cp-strcat-hot** —— G3 后默认 off。本地固定块测试相对尾指针约 221×。用 `--severity cp-strcat-hot=hint` 开启。

### 1.7 循环里的 `alloca`（cp-alloca-hot）

`alloca` 与 `__builtin_alloca` 活到函数返回。循环内调用每轮再叠一块。若不必全部保持存活，复用一块缓冲。若必须存活，栈仍会涨；带已知上界的堆缓冲是常见替代。

循环体内声明的 VLA 是另一模式，其存储随块结束。本 hint 不匹配 VLA。

hint。2026-10-22 语料裁决未覆盖本 slug。本地一次运行让每块地址保持存活：20000 次 × 64 字节覆盖 1280000 字节栈，对比单缓冲 64 字节。每块只碰两字节时约 1×，故不是加速声明。见 [evidence](../../evidence/zh-CN/cp-alloca-hot.md)。

### 1.8 大结构体按值传递（cp-struct-by-value）

按值参数在调用处复制记录。当同文件定义了该 struct、可理解成员下界至少 512 字节且至少四个字段、参数为无 `*` 的 `struct Name x` 时开火。下界按 LP64 宽度，跳过不理解的成员。数组参数不当作整记录拷贝。

hint。不是通用加速。2026-10-22 语料裁决未覆盖。512 字节记录（八个 `int` 加 `unsigned char[480]`）跨翻译单元约 12.3× 对比指针；同翻译单元静态函数约 1×（编译器消拷贝）。更小记录未达阈值。见 [evidence](../../evidence/zh-CN/cp-struct-by-value.md)。
