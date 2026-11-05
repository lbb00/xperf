# C# performance guide (v0)

Fewer reallocating lists, quieter hot paths.

> **Scope: modern C# (.NET).** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (BenchmarkDotNet, `dotnet-trace`). Runtime and GC settings differ — re-bench.

## Contents

- [1. Lists and strings](#1-lists-and-strings)
- [2. Hot I/O](#2-hot-io)
- [3. Materialize and format](#3-materialize-and-format)
- [Lint map](#lint-map)

