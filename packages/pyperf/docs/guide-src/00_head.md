# Python performance guide (v0)

Fewer quadratic builders, quieter hot paths.

> **Scope: CPython 3.10+.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`timeit`, `py-spy`, `cProfile`). PyPy and other VMs differ — re-bench.

## Contents

- [1. Strings and lists](#1-strings-and-lists)
- [2. Hot I/O](#2-hot-io)
- [3. Parse and deep copy](#3-parse-and-deep-copy)
- [Lint map](#lint-map)

