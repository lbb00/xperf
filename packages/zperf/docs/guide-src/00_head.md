# zperf: Zig Performance Guide

Less memory, more throughput.

> **Target: Zig 0.17.0.** Examples under `examples/` are checked with Zig 0.17.0 on x86_64 Linux (`zig test` Debug and `-O fast`, or `zig build-exe`). Reproduce with `cd examples && zig build test`.
> Numbers come from release notes, original PRs, or are labeled as local measurements. Nothing is invented.
>
> Companion: `zperf-lint/` — static checks for performance and memory anti-patterns (Chapter 9).

## Contents

- [0. Version notes: performance changes from 0.14 to 0.17](#0-version-notes-performance-changes-from-014-to-017)
- [1. Method: measure before changing code](#1-method-measure-before-changing-code)
- [2. Memory](#2-memory)
- [3. C memory techniques and their Zig equivalents](#3-c-memory-techniques-and-their-zig-equivalents)
- [4. Case study: reducing the memory used by a hybrid car](#4-case-study-reducing-the-memory-used-by-a-hybrid-car)
- [5. Computation](#5-computation)
- [6. Concurrency and I/O](#6-concurrency-and-io)
- [7. Builds and tooling](#7-builds-and-tooling)
- [8. Measurement and verification](#8-measurement-and-verification)
- [9. zperf-lint: find anti-patterns automatically](#9-zperf-lint-find-anti-patterns-automatically)
- [10. Quick reference](#10-quick-reference)
- [References](#references)

---

## 0. Version notes: performance changes from 0.14 to 0.17

Zig is pre-1.0; releases can break APIs. Tutorials aimed at 0.11–0.13 often no longer compile. The table below lists changes that matter for this guide (from the official release notes).

| Version | Change | Impact |
|---|---|---|
| 0.14 | `@branchHint(.likely/.unlikely/.cold/.unpredictable)` replaces `@setCold` | Branch hints use the new builtin |
| 0.14 | Labeled switches support `continue :label value` | Efficient interpreter and state-machine dispatch; the tokenizer became 13% faster |
| 0.14 | `GeneralPurposeAllocator` was rewritten and renamed `DebugAllocator`; `SmpAllocator` was added | Allocator selection changed |
| 0.14 | The Allocator vtable gained `remap`; `page_allocator` gained `mremap` support | ArrayList growth may avoid copying |
| 0.15 | **Writergate** introduced `std.Io.Writer` and `Reader`; callers provide buffers and must flush | I/O buffering APIs changed |
| 0.15 | `std.ArrayList` became unmanaged by default; `BoundedArray`, `LinearFifo`, and `RingBuffer` were removed | Container APIs changed |
| 0.16 | **I/O as an Interface** requires an `Io` value for I/O; `pub fn main(init: std.process.Init)` is the new entry point | Files, timers, and threads use `Io` |
| 0.16 | `std.Thread.Pool` was removed in favor of `Io.Group`, `io.async`, and `io.concurrent` | Parallel task APIs changed |
| 0.16 | `ArenaAllocator` became thread-safe and lock-free; `ThreadSafeAllocator` was removed | An arena can be shared across threads |
| 0.16 | `std.mem.indexOf*` was renamed to `find*`; hash maps continued the move to unmanaged containers | APIs changed |
| 0.16 / 0.17 | LLVM loop auto-vectorization was disabled to avoid miscompilations; restoration is expected in 0.18 | Explicit `@Vector` use matters more |
| 0.16 | Pointers in packed structs and unions, and runtime vector indexing, were disallowed | Packing and vector access changed |
| 0.17 | `DebugAllocator` was deprecated in favor of `SafeAllocator`, which is thread-safe and reports leaks | Debug allocator selection changed |
| 0.17 | `StackFallbackAllocator` and `std.heap.stackFallback` became `BufferFirstAllocator` | Small-buffer optimization API changed |
| 0.17 | `@backingInt` and `@fromBackingInt` replaced `@intFromEnum` and `@enumFromInt`; `@divCeil` was added | Handle, index, and division code changed |
| 0.17 | Array repetition `a ** n` was removed in favor of `@splat` | Array initialization changed |
| 0.17 | `std.builtin` became `std.lang`; `OptimizeMode` became `Optimize`, with `.debug/.safe/.fast/.small` tags; the CLI uses `-O fast` | Build scripts changed |
| 0.17 | `@bitCast` now reinterprets logical bit representations and no longer accepts extern structs; `fmt.allocPrint` became `Allocator.print`; bit-set types were renamed to `Integer`, `Static`, and `Dynamic` | Bit operations and formatting changed |

Comments beginning with `// 0.1x:` in the examples mark version-specific differences.

Sources: [0.14.0 release notes](https://ziglang.org/download/0.14.0/release-notes.html) · [0.15.1 release notes](https://ziglang.org/download/0.15.1/release-notes.html) · [0.16.0 release notes](https://ziglang.org/download/0.16.0/release-notes.html) · [0.17.0 release notes](https://ziglang.org/download/0.17.0/release-notes.html) · [downloads](https://ziglang.org/download/)

---

