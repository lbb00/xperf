# Objective-C performance guide (v0)

Foundation collection, string, and logging checklists. Distinct from [swiftperf](../../swiftperf/).

> **Scope: Objective-C (ARC or MRC).** Lint is a line-window scan of `.m`/`.h`. Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (Instruments Time Profiler / Allocations). Measure on device or macOS before escalating.

## Contents

- [1. Collections](#1-collections)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [3. Formatters, JSON, and regular expressions](#3-formatters-json-and-regular-expressions)
- [Lint map](#lint-map)

