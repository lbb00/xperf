# ArkTS performance guide (v0)

Less GC churn and shape pollution on embed / HarmonyOS hot paths.

> **Scope: ArkTS (TypeScript-like) for HarmonyOS and similar embeds.** Claims that assert speedups name a local or device bench, or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks. Related JS notes: [jsperf](../../jsperf/docs/js-performance-guide.md).

## How to read this

1. **Measure first** on device or a faithful runtime when possible.
2. Treat each chapter as a checklist.
3. Do not assume V8 numbers transfer to ArkTS VMs — re-bench.

## Contents

- [How to read this](#how-to-read-this)
- [1. Allocation](#1-allocation)
- [2. Shapes and delete](#2-shapes-and-delete)
- [3. Bridge / console chatter](#3-bridge--console-chatter)
- [4. Lookups and JSON in loops](#4-lookups-and-json-in-loops)
- [Lint map](#lint-map)

