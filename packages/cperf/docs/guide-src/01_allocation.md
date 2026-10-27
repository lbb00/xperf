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

