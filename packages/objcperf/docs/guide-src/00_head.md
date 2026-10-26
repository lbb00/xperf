# Objective-C performance guide (v0)

Foundation collection / string / logging checklists. Distinct from **swiftperf**.

> **Scope: Objective-C (ARC or MRC).** Lint is a line-window scan of `.m`/`.h`. Measure on device/macOS before escalating.

## How to read this

1. **Measure first** (Instruments Time Profiler / Allocations).
2. Treat each chapter as a checklist, not a rewrite mandate.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Collections](#1-collections)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [3. Formatters, JSON, and regular expressions](#3-formatters-json-and-regular-expressions)
- [Lint map](#lint-map)

