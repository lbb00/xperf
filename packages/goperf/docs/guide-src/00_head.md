# Go performance guide (v0)

Less allocation chatter, fewer surprise `fmt` / string-growth stalls.

> **Scope: Go 1.21+.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`go test -bench`, `pprof`, `benchstat`). Escape analysis and inlining change costs — re-bench after toolchain bumps.

## Contents

- [1. Allocation](#1-allocation)
- [2. Strings and formatting](#2-strings-and-formatting)
- [3. Compile, encode, and reflect](#3-compile-encode-and-reflect)
- [Lint map](#lint-map)

