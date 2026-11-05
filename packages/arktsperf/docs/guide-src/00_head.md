# ArkTS performance guide (v0)

Less GC churn and shape pollution on embed / HarmonyOS hot paths.

> **Scope: ArkTS (TypeScript-like) for HarmonyOS and similar embeds.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings. Related JS notes: [jsperf](../../jsperf/docs/js-performance-guide.md).

Profile first on device or a faithful runtime when you can (`DevEco` profiler, simple timers). Do not assume V8 numbers transfer to ArkTS VMs — re-bench there.

## Contents

- [1. Allocation](#1-allocation)
- [2. Shapes and delete](#2-shapes-and-delete)
- [3. Bridge / console chatter](#3-bridge--console-chatter)
- [4. Lookups and JSON in loops](#4-lookups-and-json-in-loops)
- [Lint map](#lint-map)

