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

