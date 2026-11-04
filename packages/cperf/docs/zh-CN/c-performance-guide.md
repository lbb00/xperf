# C 性能指南（v0）

少一点无谓分配，少一点意外 I/O 卡顿。

> **范围：C11 / C17。** 文中顺带提到的 C++ 备注仅在同一模式适用时成立（例如循环里的 `new` 仍是分配器开销）。凡声称加速的论断，要么有本地示例、要么有上游来源，要么标为暂定。**语料 lint 计数是启发式 dogfood**，不是基准——它告诉你检查器在哪里开火，而不是能省多少墙钟时间。
>
> 配套：`cperf-lint/` —— 十二条规则的行窗启发式（见 § Lint 对照表）。已在 quickjs、lua、gcc（稀疏）以及 sqlite `src/` 上 dogfood（2026-10-21 Asia/Shanghai）。该次运行未覆盖较晚的 hint 规则；见 [corpus.md](corpus.md)。语料树未 vendored。

## 怎么读

1. 先在真实负载上**测量**（`perf`、cachegrind；ASan 找 bug，不是测速）。
2. 把每一章当成检查清单，而不是强制重写。
3. 当 lint 打在引擎 / 编译器代码上时，先确认调用是调试、代码生成，还是有意的 CLI I/O，再谈「修」。

## 目录

- [0. 范围与方法](#0-范围与方法)
- [1. 分配](#1-分配)
- [2. 热路径 I/O](#2-热路径-io)
- [3. 测量](#3-测量)
- [4. 热路径调用](#4-热路径调用)
- [5. 标志布局](#5-标志布局)
- [Lint 对照表](#lint-对照表)
- [参考](#参考)

---

## 0. 范围与方法

进攻顺序（与共享 XPerf playbook 相同）：

1. **设计 / 批处理** —— 把网络、磁盘、内存、CPU 摊到批次上。
2. **分配形态** —— arena、池、容量倍增（§1）。
3. **热路径 I/O** —— 稳态循环里不要放 `printf` / `fprintf`（§2）。
4. **布局 / 编译器** —— SoA、`restrict`、LTO：先测；错误的 `restrict` 是 UB。
5. **验证** —— 计数器与 sanitizer（§3）。

机器侧论断应简要记录编译器、`-O` 级别和 CPU。`cp-alloc-hot`、`cp-realloc-grow-one` 与 `cp-printf-hot` 在 `evidence/` 下提供 JSONL 微基准（见 [evidence-policy.md](evidence-policy.md)）；`examples/` 下其余示例仍是模式演示（`cc -std=c17 -O2`）。

来源：[XPerf playbook](../../../../docs/zh-CN/playbook.md) · [corpus.md](corpus.md)
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

**证据（dogfood，非基准）：** 在成熟 VM 上，跳过后真正的热路径「循环 malloc」很少。r2 包装 / 花括号修复后：quickjs cp-alloc-hot **0**；lua cp-alloc-hot **0**。剩余压力主要在紧凑树与胶水：sqlite `src/` r3 **14**（如 `tclsqlite.c` 行循环里 realloc）；gcc 稀疏 r3 **28**。单行 `return realloc(...)` 包装在 r1 是误报（r2 已清）。把 cp-alloc-hot 命中当作评审提示——按已知 N 只分配一次的初始化循环往往没问题。

### 1.2 无容量的增长（cp-realloc-grow-one）

反复 `realloc(p, n + 1)`（或 `old + 1`）是平方级并会搬缓冲。分开跟踪 `len` 与 `cap`；按倍增（或其他固定因子）增长。

Lint：**cp-realloc-grow-one** —— 对 grow-by-one 的尽力正则。

**实测证据（error 档）：** [`evidence/cp-realloc-grow-one.md`](../../evidence/zh-CN/cp-realloc-grow-one.md) · [`cp-realloc-grow-one.jsonl`](../../evidence/cp-realloc-grow-one.jsonl) —— realloc(+1) 对比容量倍增约 **12.6×**（N=1e5）；配套 STATIC-VS-O2 case4 约 **3×**。严重级别 **error**。

**证据（dogfood）：** 在引擎语料上几乎从不开火——quickjs / lua **0**；gcc 稀疏 **1**；sqlite **1**（r3）。成熟代码里该模式少见；实测门禁仍会让绿地增长在 `--preset app` 下失败。

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

`for (i = 0; i < strlen(s); i++)` 每次迭代重算长度（常为 O(n²)）。提升 `size_t n = strlen(s)`（或用已知长度）。Lint：**cp-strlen-in-cond** —— 默认 **hint**。编译器必须重算时约 125×；`-O2` 能提升时约 1×。

### 1.6 循环里的 `strcat`（cp-strcat-hot）

反复 `strcat`/`strncat` 每次从起点扫目标。优先用尾指针 + `memcpy`，或可用时用 `stpcpy`。Lint：**cp-strcat-hot** —— G3 后默认 **off**。本地固定块测试相对尾指针约 221×。用 `--severity cp-strcat-hot=hint` 开启。

### 1.7 循环里的 `alloca`（cp-alloca-hot）

`alloca` 与 `__builtin_alloca` 活到函数返回。循环内调用每轮再叠一块。若不必全部保持存活，复用一块缓冲。若必须存活，栈仍会涨；带已知上界的堆缓冲是常见替代。

循环体内声明的 VLA 是另一模式，其存储随块结束。本 hint 不匹配 VLA。

**hint**。2026-10-22 语料裁决未覆盖本 slug。本地一次运行让每块地址保持存活：20000 次 × 64 字节覆盖 1280000 字节栈，对比单缓冲 64 字节。每块只碰两字节时约 1×，故不是加速声明。见 [evidence](../../evidence/zh-CN/cp-alloca-hot.md)。

### 1.8 大结构体按值传递（cp-struct-by-value）

按值参数在调用处复制记录。当同文件定义了该 struct、可理解成员下界至少 512 字节且至少四个字段、参数为无 `*` 的 `struct Name x` 时开火。下界按 LP64 宽度，跳过不理解的成员。数组参数不当作整记录拷贝。

**hint**。不是通用加速。2026-10-22 语料裁决未覆盖。512 字节记录（八个 `int` 加 `unsigned char[480]`）跨翻译单元约 12.3× 对比指针；同翻译单元静态函数约 1×（编译器消拷贝）。更小记录未达阈值。见 [evidence](../../evidence/zh-CN/cp-struct-by-value.md)。
## 2. 热路径 I/O

### 2.1 循环里的 `printf` / `fprintf`（cp-printf-hot）

紧循环里的格式化与 stdio 锁往往盖过你本想测量的工作。优先：

- 先攒到缓冲；批次结束再写一次。
- 把调试打印关在 `#ifdef DUMP` / `#ifdef DEBUG`（或运行时 `if (dump_file)`）后面。
- 量大时用二进制 / 长度前缀日志。

Lint：**cp-printf-hot** —— 循环体窗口内的 `printf` / `fprintf` / `puts`（及同类）。

**实测证据（部分同意；默认 off）：** [`evidence/cp-printf-hot.md`](../../evidence/zh-CN/cp-printf-hot.md) · [`cp-printf-hot.jsonl`](../../evidence/cp-printf-hot.jsonl) —— 热路径无缓冲对比缓冲 fprintf 约 **4.8×**（N=8e4）；静默天花板约 **561×**。STATIC-VS-O2 case3 `#if 0` / 死 dump ≈ **1.0×** 却静态开火 → 保持低于 **error**（默认 **off**）。见 [evidence-policy.md](evidence-policy.md)。

### 2.2 有意的 dump / 调试

引擎与编译器树里充满**正确**的循环打印：RTL dump、strlen dump、atom 泄漏追踪、字节码 dump。启发式上 cp-printf-hot 说得对（「这是循环里的 I/O」）；对那些树做 CI 时，操作上却是噪声。

**cperf-lint 抑制（r2–r3）：**

- 函数名匹配 `dump|debug|trace|log_`，或以 `print` 开头/结尾（不含 `sprintf`）。
- 匹配 `DUMP|DEBUG|ENABLE_*DUMP|GATHER_STATISTICS|ENABLE_CHECKING` 的 `#if` / `#ifdef` / `#elif` 帧。
- 调用行上的 dump 流：`*dump_file`、`*_dump`、`dump_*`、`sched_dump`、`asm_out_file`、`stderr`。
- 上一行 `if (dump_*)` 或 `#if…DUMP|DEBUG`。
- 多行 `#define` 体（行以 `\` 结束）——头文件里的 asm 发射器。
- 路径跳过：`gen*.c/cc`、`*generate*`、`*dump*` 源、`bitintpow10*`、…

夹具：`fixtures/good/dump_printf_loop.c`、`ifdef_dump_printf.c`、`dump_file_fprintf.c`。

### 2.3 语料残留（启发式 dogfood）

路径跳过 + 抑制后的计数。**不是**「printf 多少毫秒」。

| 语料 | r1 → r2 → r3（cp-printf-hot-heavy 合计） | 备注 |
|------|------------------------------------------|------|
| quickjs | 258 → 76 → **62**（r3 全为 cp-printf-hot） | 残留：`quickjs.c` atom/调试 printf（~29）、`dtoa.c` 表发射（~15）、`qjsc.c` 进度、`libregexp.c` / `libunicode.c` 统计 |
| lua | 3 → 2 → **1** | 跳过后很安静 |
| gcc 稀疏 | — → 4392 → **357**（cp-printf-hot:328） | 已达低于 500 目标；主要残留：`collect2.cc` ctor 列表写（~49）、`tree-ssa-strlen.cc` dump（~31）、`mkdeps.cc`（~27）、`reload.cc`（~20）、`makeucnid.cc` 表发射（~11） |
| sqlite `src/` | — → — → **93**（cp-printf-hot:78） | `treeview.c` 调试树（~25）、`vdbe.c` / `vdbeaux.c` plan/字节码 dump、`bitvec.c` 测试 dump |

**怎么读残留路径：** `collect2` / `mkdeps` / `makeucnid` / `dtoa` 表生成是**代码生成写入器**——循环 `fprintf` 就是产物。可选的未来安静模式：路径白名单或「codegen writer」抑制。不要因为 lint 开火就把有意的发射器「优化掉」。

### 2.4 CLI 工具

`qjsc.c` 一类 CLI 里的 `fprintf(stderr, …)` 进度往往可接受。优先限速或 `--verbose` 门控，而不是删掉用户可见进度。
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
## 4. 热路径调用

热循环不应每轮格式化新字符串、打开文件、采样时钟或编译正则。写到已有缓冲、流只开一次、时钟读在稳态外、模式只编译一次。这些 lint 是 **hint**。2026-10-22 语料裁决未覆盖它们。

- **cp-sprintf-hot** —— 循环体内的 `sprintf` 或 `snprintf`。有 JSONL。保持 hint，未做语料 triage。
- **cp-fopen-hot** —— 循环体内的 `fopen`。有 JSONL。保持 hint，未做语料 triage。
- **cp-gettime-hot** —— 循环体内的 `gettimeofday` 或 `clock_gettime`。裸 `time` 不匹配（名字太宽）。有 JSONL。保持 hint，未做语料 triage。
- **cp-regex-hot** —— 循环体内的 `regcomp`。不匹配 `regexec`。微基准相对「编译一次」约 9.7×。保持 **hint**，未做语料 triage。

夹具命中不等于实测加速。见 [evidence-policy.md](evidence-policy.md)。
## 5. 标志布局

一条记录上的若干开关属性（例如某车有哪些动力源），在大量副本共享紧张 RAM 预算时，不必每个都占满一个整数。混合（电动与汽油并存）是位组合，不是互斥枚举值。

要紧的是 `sizeof`，它包含对齐填充。四个 `int` 标志占四个 `int`：`int` 16 位时 8 字节，32 位时 16。位域宽度不是那个尺寸。`unsigned` 位域常存进一个 `unsigned int`，所以四个 1 位字段仍可能占 4 字节。`unsigned char` 位域可共享一字节。单个 `unsigned` 掩码是另一种紧凑形式。在你交付的 ABI 上检查 `sizeof`。

关掉对齐或 packing pragma 是目标选择。有的 CPU 对未对齐加载会故障或变慢。本 hint 不要求那样做。

**cp-wide-bool-flags** 在一个 struct 有四个及以上全宽 `bool` / `_Bool` 成员，或四个及以上名为 `is_` / `has_` / `can_` 的 `int` / `unsigned` 成员、且没有位域时开火。这是 **hint**。有 JSONL。保持 hint；2026-10-22 语料裁决未覆盖。桌面上少量记录可以忽略。JVM 上类似的对象头规则在测量显示无占用收益后已移除；本 C hint 不是那次测量。

夹具命中不等于实测节省。见 [evidence-policy.md](evidence-policy.md)。
## Lint 对照表

| ID | 主题 | 严重级别 / 备注 |
|----|------|-----------------|
| cp-alloc-hot | 循环内 malloc/calloc/realloc | **error** — 有证据；VM 上少见；sqlite/gcc 十余到数十 |
| cp-realloc-grow-one | 无容量的 realloc 增长 | **error** — 有证据；成熟树几乎从不开火 |
| cp-printf-hot | 循环内 printf/fprintf/puts | 默认 **off** — 热路径 YES / 死代码 NEGATIVE；需要 dump 抑制 |
| cp-strlen-in-cond | 循环条件里的 strlen | **hint** — 重算约 125×，能提升约 1× |
| cp-strcat-hot | 循环内 strcat/strncat | 默认 **off** — 约 221×；冷 CLI/路径可接受 |
| cp-sprintf-hot | 循环内格式化写缓冲 | **hint** — 有 JSONL；未做语料 triage |
| cp-fopen-hot | 循环内打开文件 | **hint** — 有 JSONL；未做语料 triage |
| cp-gettime-hot | 循环内采样时钟（不含裸 `time`） | **hint** — 有 JSONL；未做语料 triage |
| cp-wide-bool-flags | 同一 struct 四个及以上全宽布尔标志 | **hint** — 有 JSONL；未做语料 triage |
| cp-regex-hot | 循环内 `regcomp`（不匹配 `regexec`） | **hint** — JSONL 约 9.7×；未做语料 triage |
| cp-alloca-hot | 循环内 `alloca` / `__builtin_alloca`（不匹配 VLA） | **hint** — 测过栈覆盖；墙钟约 1×；未做语料 triage |
| cp-struct-by-value | 可见下界 ≥512 字节且 ≥4 字段的 struct 按值参数 | **hint** — JSONL 跨 TU 约 12.3×；未做语料 triage |

## 参考

- [corpus.md](corpus.md) — clone pin 与 r2→r3 表
- 共享方法：[XPerf playbook](../../../../docs/zh-CN/playbook.md)
- 布局演示：`examples/p01_soa.c`、`examples/p02_restrict_note.c`
