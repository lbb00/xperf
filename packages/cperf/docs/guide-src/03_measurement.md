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
