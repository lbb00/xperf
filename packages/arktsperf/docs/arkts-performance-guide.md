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

## 1. Allocation

Object and array literals, and `new`, inside tight UI or animation loops raise GC pressure. Reuse buffers when the profile shows pressure.

Lint: `at-alloc-hot` (default off).

## 2. Shapes and delete

`delete` and mixed property shapes push polymorphic paths. Prefer stable object layouts (same idea as V8 hidden classes — re-bench on ArkTS).

A Node proxy of `delete` versus `Map.delete` was about 1×, so there is no lint for it. Re-bench on an ArkTS VM before adding one.

## 3. Bridge / console chatter

`console.log` and frequent sync cross-language or worker bridge calls on the hot path stall frames. Gate debug I/O.

Lint: `at-console-hot` (default off).

## 4. Lookups and JSON in loops

`Array.includes` / `indexOf` over a list inside a hot loop is linear per iteration; build a `Set` once and use `has`. For short strings, a dense lookup table beats `Map` (a `Map` often loses on short haystacks). Parsing or stringifying many small JSON values in a loop repeats allocation and parsing work; parse one array blob or reuse buffers.

Lint: `at-includes-hot`, `at-json-hot` (both default hint). Their JSONL evidence is a Node proxy, not an ArkTS VM, so it cannot raise severity on its own.

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| at-alloc-hot | alloc-like in loop | off |
| at-console-hot | console / bridge chatter in loop | off |
| at-includes-hot | `includes` / `indexOf` in loop | hint |
| at-json-hot | `JSON.parse` / `stringify` in loop | hint |

Escalate only with a device or ArkTS-VM bench on top of `evidence/at-*.jsonl` (see [evidence-policy.md](evidence-policy.md)).

## References

- [XPerf playbook](../../../docs/playbook.md)
- [jsperf guide](../../jsperf/docs/js-performance-guide.md) (related, not identical)
