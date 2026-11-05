# Ruby performance guide (v0)

Fewer quadratic builders, quieter hot paths.

> **Scope: MRI Ruby 3+.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`benchmark`, stackprof). JRuby and TruffleRuby differ — re-bench.

## Contents

- [1. Strings, arrays, and hashes](#1-strings-arrays-and-hashes)
- [2. Hot I/O](#2-hot-io)
- [3. Compile and parse](#3-compile-and-parse)
- [Lint map](#lint-map)

