# C++ performance guide (v0)

Fewer reallocating containers, quieter hot paths.

> **Scope: C++17.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.
>
> **cppperf vs cperf:** this kit is dedicated C++. Sibling **cperf** covers C11/C17 (+ light C++). Prefer this package for `std::vector` / `std::string` / iostream smells.

Profile first (`perf`, Tracy, `std::chrono`). libstdc++ and libc++ differ — re-bench.

## Contents

- [1. Containers and strings](#1-containers-and-strings)
- [2. Hot I/O](#2-hot-io)
- [3. Regex, flush, and the clock](#3-regex-flush-and-the-clock)
- [Lint map](#lint-map)

