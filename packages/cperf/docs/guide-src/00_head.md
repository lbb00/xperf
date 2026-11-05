# C performance guide (v0)

Less allocation chatter, fewer surprise I/O stalls.

> **Scope: C11 / C17.** C++ remarks are incidental where the same pattern applies (e.g. `new` in a loop is still an allocator hit). Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.
>
> Companion: `cperf-lint/` — twelve line-window rules (see Lint map). Run against quickjs, lua, gcc (sparse), and sqlite `src/` (2026-10-21 Asia/Shanghai). That run does not cover the later hint rules; see [corpus.md](corpus.md). Corpus trees are not vendored.

Profile first on a real workload (`perf`, cachegrind; ASan for bugs, not speed). When a lint fires on engine or compiler code, check whether the call is debug, codegen, or intentional CLI I/O before changing it.

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

1. Design / batching — amortize network, disk, memory, and CPU across batches.
2. Allocation shape — arenas, pools, capacity doubling (§1).
3. Hot I/O — keep `printf` / `fprintf` out of steady-state loops (§2).
4. Layout / compiler — SoA, `restrict`, LTO: measure; wrong `restrict` is UB.
5. Verify — counters and sanitizers (§3).

Machine claims should record compiler, `-O` level, and CPU briefly. `cp-alloc-hot`, `cp-realloc-grow-one`, and `cp-printf-hot` ship JSONL microbenches under `evidence/` (see [evidence-policy.md](evidence-policy.md)); other examples under `examples/` remain pattern demos (`cc -std=c17 -O2`).

Sources: [XPerf playbook](../../../docs/playbook.md) · [corpus.md](corpus.md)
