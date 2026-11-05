# Rust performance guide (v0)

Less allocator chatter, fewer surprise string / print stalls.

> **Scope: Rust edition 2021+.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`cargo bench`, `criterion`, `perf`). LLVM optimizations change costs — re-bench after toolchain bumps.

## Contents

- [1. Allocation and clone](#1-allocation-and-clone)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [3. Regex](#3-regex)
- [Lint map](#lint-map)

