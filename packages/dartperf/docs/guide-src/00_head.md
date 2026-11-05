# Dart performance guide (v0)

Fewer list resizes, fewer string `+` temporaries, quieter hot loops.

> **Scope: Dart 3.x (VM / Flutter).** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`benchmark_harness`, DevTools CPU profiler). Treat chapters as checklists, not rewrite mandates.

## Contents

- [1. Lists](#1-lists)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [Lint map](#lint-map)

