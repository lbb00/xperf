# C performance guide (v0)

Less allocation chatter, fewer surprise I/O stalls.

> **Scope: C11 / C17.** C++ remarks are incidental where the same pattern applies (e.g. `new` in a loop is still an allocator hit). Claims that assert speedups name a local example, an upstream source, or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks — they tell you where the checker fires, not how much wall time you would save.
>
> Companion: `cperf-lint/` — line-window heuristics for twelve rules (see § Lint map). Dogfooded on quickjs, lua, gcc (sparse), and sqlite `src/` (2026-10-21 Asia/Shanghai). That run does not cover the later hint rules; see [corpus.md](corpus.md). Corpus trees are not vendored.

## How to read this

1. **Measure first** on a real workload (`perf`, cachegrind, ASan for bugs — not for speed).
2. Treat each chapter as a checklist, not a rewrite mandate.
3. When a lint fires on engine / compiler code, check whether the call is debug, codegen, or intentional CLI I/O before “fixing” it.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Allocation](#1-allocation)
- [2. Hot I/O](#2-hot-io)
- [3. Measurement](#3-measurement)
- [4. Hot calls](#4-hot-calls)
- [5. Flag layout](#5-flag-layout)
- [Lint map](#lint-map)
- [References](#references)

---

## 0. Scope and method

Order of attack (same as the shared XPerf playbook):

1. **Design / batching** — amortize network, disk, memory, CPU across batches.
2. **Allocation shape** — arenas, pools, capacity doubling (§1).
3. **Hot I/O** — keep `printf` / `fprintf` out of steady-state loops (§2).
4. **Layout / compiler** — SoA, `restrict`, LTO: measure; wrong `restrict` is UB.
5. **Verify** — counters and sanitizers (§3).

Machine claims should record compiler, `-O` level, and CPU briefly. `cp-alloc-hot`, `cp-realloc-grow-one` and `cp-printf-hot` ship JSONL microbenches under `evidence/` (see [evidence-policy.md](evidence-policy.md)); other examples under `examples/` remain pattern demos (`cc -std=c17 -O2`).

Sources: [XPerf playbook](../../../docs/playbook.md) · [corpus.md](corpus.md)

## 1. Allocation

### 1.1 Hot-path `malloc` / `calloc`

`malloc` / `free` in a tight loop pays allocator overhead, can fragment, and adds failure paths to every iteration. Prefer:

| Pattern | When |
|---------|------|
| **Arena** (bump pointer; free / reset all at once) | Same lifetime: request, frame, parse, batch |
| **Size-class pool** | Many equal-sized objects; checkout / release |
| **Stack / VLA / fixed buffer** | Bound known and small; lifetime nested in the caller |
| **Hoist out of the loop** | One buffer reused across iterations |

See `examples/m01_arena.c`.

Lint: **cp-alloc-hot** — `malloc` / `calloc` / `realloc` inside a `for` / `while` / `do` body (brace-depth heuristic).

**Measured evidence (error-tier):** [`evidence/cp-alloc-hot.md`](../evidence/cp-alloc-hot.md) · [`cp-alloc-hot.jsonl`](../evidence/cp-alloc-hot.jsonl) — `cc -std=c11 -O2` (Debian gcc 14.2.0), malloc+free per iter vs arena bump ~**10.8×** (N=2e5, median of 9). Policy: [evidence-policy.md](evidence-policy.md). Harness: `examples/bench/cp001_malloc_vs_arena.c`.

**Evidence (dogfood, not bench):** On mature VMs, true hot-path `malloc`-in-loop is rare after skips. After r2 wrapper / brace fixes: quickjs cp-alloc-hot **0**; lua cp-alloc-hot **0**. Remaining cp-alloc-hot pressure is mostly compact trees and glue: sqlite `src/` r3 **14** cp-alloc-hot (e.g. `tclsqlite.c` realloc in a line loop); gcc sparse r3 **28** cp-alloc-hot. Thin `return realloc(...)` wrappers were false positives in r1 (cleared in r2). Treat cp-alloc-hot hits as review prompts — init loops that allocate once per known N are often fine.

### 1.2 Growth without capacity (cp-realloc-grow-one)

Repeated `realloc(p, n + 1)` (or `old + 1`) is quadratic and moves buffers. Track `len` and `cap` separately; grow by doubling (or another fixed factor).

Lint: **cp-realloc-grow-one** — best-effort regex for `realloc` grow-by-one.

**Measured evidence (error-tier):** [`evidence/cp-realloc-grow-one.md`](../evidence/cp-realloc-grow-one.md) · [`cp-realloc-grow-one.jsonl`](../evidence/cp-realloc-grow-one.jsonl) — realloc(+1) vs capacity doubling ~**12.6×** (N=1e5); companion STATIC-VS-O2 case4 ~**3×**. Severity **error**.

**Evidence (dogfood):** Almost never fired on engine corpora — quickjs / lua **0**; gcc sparse **1**; sqlite **1** (r3). Pattern is uncommon in mature code; the measured gate still makes greenfield growth fail CI under `--preset app`.

### 1.3 What corpora taught about noise

| Noise class | Example | Response in cperf-lint |
|-------------|---------|------------------------|
| Generated / harness | `unicode_gen.c`, `fuzz/`, `run-test262.c`, `ltests.c` | Path skips |
| Thin allocator wrappers | `return realloc(p, n);` | Skip single-statement wrappers (r2) |
| Brace-less `for` attaching next stmt | one-line loop then wrapper | `pending_loop` cleared (r2) |

Path skips also cover gcc `testsuite/`, `gen*.c/cc`, `*generate*`, `generated/`, `*dump*` sources. Full inventory: [corpus.md](corpus.md).

### 1.4 Provisional

RSS spikes from unbounded freelists / caches need a working-set cap — not measured in-tree yet. SoA vs AoS: `examples/p01_soa.c` (layout demo, no timing claim).

### 1.5 `strlen` in loop condition (cp-strlen-in-cond)

`for (i = 0; i < strlen(s); i++)` recomputes length every iteration (often O(n²)). Hoist `size_t n = strlen(s)` (or use a known length). Lint: **cp-strlen-in-cond** — default **hint**. About 125× when the compiler must recompute the length; about 1× when `-O2` hoists it.

### 1.6 `strcat` in a loop (cp-strcat-hot)

Repeated `strcat`/`strncat` walks the destination from the start each time. Prefer an end pointer + `memcpy`, or `stpcpy` where available. Lint: **cp-strcat-hot** — default **off** after G3. A local run of fixed chunks was about 221× an end pointer. Enable with `--severity cp-strcat-hot=hint`.

### 1.7 `alloca` in a loop (cp-alloca-hot)

`alloca` and `__builtin_alloca` live until the function returns. A call in a loop adds another block on every pass. Reuse one buffer when those bytes do not all have to stay live. If they do, the stack still grows; a heap buffer with a known bound is the usual alternative.

A VLA declared in the loop body is a different pattern. Its storage ends with the block. This hint does not match a VLA.

**hint**. The 2026-10-22 corpus verdict does not cover this slug. One local run kept every block address live: 20000 iterations of 64 bytes covered 1280000 bytes of stack, against 64 bytes for one buffer. Touching two bytes of each block was about 1×, so this is not a speedup claim. See [evidence](../evidence/cp-alloca-hot.md).

### 1.8 Large struct by value (cp-struct-by-value)

A by-value parameter copies the record at the call. The hint fires for `struct Name x` with no `*` when that struct is defined in the same file, a lower bound of the members it understands is at least 512 bytes, and there are at least four such fields. The lower bound uses LP64 widths and skips members it does not understand. An array parameter is not treated as a copy of the record.

**hint**. Not a general speedup. The 2026-10-22 corpus verdict does not cover this slug. A 512-byte record (eight `int`s plus `unsigned char[480]`) called from another translation unit was about 12.3× versus a pointer. The same shape as a static function in one translation unit was about 1× because the compiler removed the copy. Smaller records stayed under the bar and are not matched. See [evidence](../evidence/cp-struct-by-value.md).

## 2. Hot I/O

### 2.1 `printf` / `fprintf` in a loop (cp-printf-hot)

Formatting and stdio locking in a tight loop dwarf the work you meant to measure. Prefer:

- Accumulate into a buffer; one write at the end of the batch.
- Gate debug printers behind `#ifdef DUMP` / `#ifdef DEBUG` (or a runtime `if (dump_file)`).
- Use binary / length-prefixed logs when volume is high.

Lint: **cp-printf-hot** — `printf` / `fprintf` / `puts` (and friends) inside a loop-body window.

**Measured evidence (partial agreement; default off):** [`evidence/cp-printf-hot.md`](../evidence/cp-printf-hot.md) · [`cp-printf-hot.jsonl`](../evidence/cp-printf-hot.jsonl) — hot unbuffered vs buffered fprintf ~**4.8×** (N=8e4); silent ceiling ~**561×**. STATIC-VS-O2 case3 `#if 0` / dead dump ≈ **1.0×** with static fire → keep below **error** (default **off**). See [evidence-policy.md](evidence-policy.md).

### 2.2 When dump / debug is intentional

Engine and compiler trees are full of **correct** looped printers: RTL dumps, strlen dumps, atom leakage traces, bytecode dumps. Heuristically cp-printf-hot is right (“this is I/O in a loop”); operationally it is noise for CI on those trees.

**cperf-lint suppressions (r2–r3):**

- Function names matching `dump|debug|trace|log_`, or starting/ending with `print` (not `sprintf`).
- `#if` / `#ifdef` / `#elif` frames matching `DUMP|DEBUG|ENABLE_*DUMP|GATHER_STATISTICS|ENABLE_CHECKING`.
- Dump streams on the call line: `*dump_file`, `*_dump`, `dump_*`, `sched_dump`, `asm_out_file`, `stderr`.
- Previous line `if (dump_*)` or `#if…DUMP|DEBUG`.
- Multi-line `#define` bodies (line ends with `\`) — asm emitters in headers.
- Path skips: `gen*.c/cc`, `*generate*`, `*dump*` sources, `bitintpow10*`, …

Fixtures: `fixtures/good/dump_printf_loop.c`, `ifdef_dump_printf.c`, `dump_file_fprintf.c`.

### 2.3 Corpus residual (heuristic dogfood)

Counts after path skips + suppressions. **Not** “printf cost in ms”.

| Corpus | r1 → r2 → r3 (cp-printf-hot-heavy totals) | Notes |
|--------|-------------------------------------|-------|
| quickjs | 258 → 76 → **62** (all cp-printf-hot at r3) | Residual: `quickjs.c` atom/debug printf (~29), `dtoa.c` table emitter (~15), `qjsc.c` progress, `libregexp.c` / `libunicode.c` stats |
| lua | 3 → 2 → **1** | Quiet after skips |
| gcc sparse | — → 4392 → **357** (cp-printf-hot:328) | Under-500 target met; top residual: `collect2.cc` ctor-list writers (~49), `tree-ssa-strlen.cc` dump (~31), `mkdeps.cc` (~27), `reload.cc` (~20), `makeucnid.cc` table emitter (~11) |
| sqlite `src/` | — → — → **93** (cp-printf-hot:78) | `treeview.c` debug tree (~25), `vdbe.c` / `vdbeaux.c` plan/bytecode dump, `bitvec.c` test dump |

**Reading residual paths:** `collect2` / `mkdeps` / `makeucnid` / `dtoa` table gens are **codegen writers** — looped `fprintf` is the product. Optional future quiet mode: path allowlist or “codegen writer” suppress. Do not “optimize away” intentional emitters because the lint fired.

### 2.4 CLI tools

`fprintf(stderr, …)` progress in `qjsc.c`-style CLIs is often acceptable. Prefer rate-limiting or a `--verbose` gate rather than deleting user-visible progress.

## 3. Measurement

Short and honest: this kit does not replace `perf`. Use the tools below to decide whether a cperf-lint hit matters.

### 3.1 Wall and counters

```sh
perf stat -e cycles,instructions,cache-misses,branch-misses,task-clock -- ./app
perf record -g -- ./app && perf report   # keep frame pointers when possible
```

Record compiler (`cc -v`), flags (`-O2` / `-O3` / `-flto`), OS, and CPU model. Compare distributions (best-of-N or median), not one sample.

### 3.2 Cachegrind / callgrind

`valgrind --tool=cachegrind ./app` simulates cache behavior; useful when PMCs are unavailable. Slow; not for CI gates on large trees.

### 3.3 Sanitizers are not speed tools

ASan / TSan / UBSan find bugs. They inflate time and RSS. Use them on the same change set that touches allocators or races; quote numbers from **unsanitized** Release builds only.

### 3.4 Measured gates vs dogfood

In-tree JSONL under `evidence/` (see [evidence-policy.md](evidence-policy.md)):

| Rule | Severity | Wall-clock (local run) |
|------|----------|------------------------|
| cp-alloc-hot | **error** | ~10.8× malloc-in-loop vs arena |
| cp-realloc-grow-one | **error** | ~12.6× realloc(+1) vs doubling |
| cp-printf-hot | **off** (default) | ~4.8× hot unbuf/buf; `#if 0` ~1.0× → partial |
| cp-strlen-in-cond | **hint** | about 125× if the string can change; about 1× if hoisted |
| cp-strcat-hot | **off** (default) | about 221×; stays off |
| cp-sprintf-hot | **hint** | JSONL present; stays hint; not corpus-triaged |
| cp-fopen-hot | **hint** | JSONL present; stays hint; not corpus-triaged |
| cp-gettime-hot | **hint** | JSONL present; stays hint; not corpus-triaged |
| cp-wide-bool-flags | **hint** | JSONL present; stays hint; not corpus-triaged |
| cp-regex-hot | **hint** | JSONL about 9.7×; not corpus-triaged |
| cp-alloca-hot | **hint** | stack 1280000 vs 64 bytes; wall clock about 1×; not corpus-triaged |
| cp-struct-by-value | **hint** | JSONL about 12.3× cross-TU; same TU about 1×; not corpus-triaged |

Corpus residual counts (§2.3) remain lint dogfood only. Pattern demos (`examples/m01_arena.c`) still illustrate APIs without replacing the JSONL gate.
## 4. Hot calls

A hot loop should not format a new string, open a file, sample the clock, or compile a regular expression on every pass. Format into a buffer you already have, open the stream once, read the clock outside the steady state, and compile a pattern once. These lints are **hint**. The 2026-10-22 corpus verdict does not cover them.

- **cp-sprintf-hot** — `sprintf` or `snprintf` in a loop body. JSONL is present. The rule stays hint and is not corpus-triaged.
- **cp-fopen-hot** — `fopen` in a loop body. JSONL is present. The rule stays hint and is not corpus-triaged.
- **cp-gettime-hot** — `gettimeofday` or `clock_gettime` in a loop body. A bare `time` call is not matched; that name is too broad. JSONL is present. The rule stays hint and is not corpus-triaged.
- **cp-regex-hot** — `regcomp` in a loop body. `regexec` is not matched. A microbench was about 9.7× versus compiling once. The rule stays **hint** and is not corpus-triaged.

A fixture hit is not a measured speedup. See [evidence-policy.md](evidence-policy.md).
## 5. Flag layout

Several on/off properties of one record, such as which power sources a vehicle has, do not each need a full integer when many copies of that record share a tight RAM budget. A mix (electric and gasoline together) is a combination of bits, not one exclusive enum value.

`sizeof` is the size that matters, and it includes alignment padding. Four `int` flags occupy four `int`s. Where `int` is 16 bits that is 8 bytes; where `int` is 32 bits it is 16. A bit-field width is not that size. `unsigned` bit-fields are commonly stored in an `unsigned int`, so four 1-bit fields can still occupy 4 bytes. `unsigned char` bit-fields can share one byte. A single `unsigned` mask is the other compact form. Check `sizeof` on the ABI you ship.

Turning alignment off, or a packing pragma, is a target choice. Some CPUs fault or slow down on unaligned loads. This hint does not ask for that.

**cp-wide-bool-flags** fires when one struct has four or more full-width `bool` or `_Bool` members, or four or more `int` / `unsigned` members named `is_`, `has_`, or `can_`, and the struct has no bit-field. It is a **hint**. JSONL is present. The rule stays hint, and the 2026-10-22 corpus verdict does not cover it. A handful of records on a desktop can ignore it. A similar object-header rule on the JVM was removed after measurement showed no footprint win; this C hint is not that measurement.

A fixture hit is not a measured saving. See [evidence-policy.md](evidence-policy.md).
## Lint map

| ID | Topic | Severity / note |
|----|--------|-----------------|
| cp-alloc-hot | malloc/calloc/realloc in loop | **error** — evidence; rare on VMs; sqlite/gcc teens–tens |
| cp-realloc-grow-one | realloc grow without capacity | **error** — evidence; almost never on mature trees |
| cp-printf-hot | printf/fprintf/puts in loop | **off** by default — hot YES / dead NEGATIVE; dump suppressions required |
| cp-strlen-in-cond | strlen in loop condition | **hint** — about 125× if recomputed, about 1× if hoisted |
| cp-strcat-hot | strcat/strncat in loop | **off** by default — about 221×; cold CLI/path OK-idiom |
| cp-sprintf-hot | formatted buffer write in loop | **hint** — JSONL present; not corpus-triaged |
| cp-fopen-hot | file open in loop | **hint** — JSONL present; not corpus-triaged |
| cp-gettime-hot | clock sample in loop (not bare `time`) | **hint** — JSONL present; not corpus-triaged |
| cp-wide-bool-flags | four or more full-width boolean flags in one struct | **hint** — JSONL present; not corpus-triaged |
| cp-regex-hot | `regcomp` in a loop (`regexec` is not matched) | **hint** — JSONL about 9.7×; not corpus-triaged |
| cp-alloca-hot | `alloca` / `__builtin_alloca` in a loop (a VLA is not matched) | **hint** — stack cover measured; wall clock about 1×; not corpus-triaged |
| cp-struct-by-value | by-value parameter of a struct whose visible lower bound is at least 512 bytes and four fields | **hint** — JSONL about 12.3× cross-TU; not corpus-triaged |

## References

- [corpus.md](corpus.md) — clone pins and r2→r3 tables
- Shared method: [XPerf playbook](../../../docs/playbook.md)
- Layout demos: `examples/p01_soa.c`, `examples/p02_restrict_note.c`
