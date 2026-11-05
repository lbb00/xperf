# Swift performance guide (v0)

Fewer force-unwraps on hot paths, fewer quadratic string builders.

> **Scope: Swift 5.9+.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (Instruments, `swift package benchmark` when available). ARC and specialization change costs — re-bench after toolchain bumps.

## Contents

- [1. Optionals and hot paths](#1-optionals-and-hot-paths)
- [2. Strings, collections, and printing](#2-strings-collections-and-printing)
- [3. Formatters, JSON, and regular expressions](#3-formatters-json-and-regular-expressions)
- [Lint map](#lint-map)

