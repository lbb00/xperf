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
