# PHP performance guide (v0)

Fewer quadratic builders, quieter hot paths.

> **Scope: PHP 8+.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`hrtime`, Blackfire, Xdebug). Extensions and JIT differ — re-bench.

## Contents

- [1. Strings and arrays](#1-strings-and-arrays)
- [2. Hot I/O](#2-hot-io)
- [Lint map](#lint-map)

