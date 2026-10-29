# JavaScript performance guide (v0)

Stable shapes, fewer per-iteration allocations — plus a separate chapter on tooling / cold-start.

> **Focus: modern Node and V8 ICs / GC.** QuickJS and 小程序-like embeds get a dedicated chapter (§3) — avoid advice that only makes sense with a DOM or a full browser profiler. **§4 deepens V8** (maps, elements kinds, deopts, Ignition→Maglev/Turbofan); it does **not** apply to §3 runtimes. **§5** covers **startup and tooling** (module resolution, eager graphs, barrels) after Marvin Hagemeister’s ecosystem series — orthogonal to the jp-* lint rules.
>
> Claims that assert speedups name a local example, an upstream source, or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks. §4.6 cites single-machine microbench medians only. §5 cites Marvin’s **methods** (URLs); re-measure his timings locally.
>
> Companion: `jsperf-lint/` — the jp-* rules, see the [Lint map](#lint-map) (line windows; not a full parser). Dogfooded on Node `lib/`, Preact `src/`, quickjs `*.js` (tests skipped), and TypeScript `packages/typescript/src` (2026-10-21 Asia/Shanghai). See [corpus.md](corpus.md). Startup/FS cost is **out of band** for the jp-* rules — see §5.

## How to read this

1. Profile first (`node --prof`, `node --cpu-prof` + speedscope, Chrome Performance, clinic). Lint findings are review prompts.
2. Prefer consistent object shapes and batch allocation over micro-optimizing single property access.
3. Embed / 小程序 runtimes: skip DOM-only tips; watch alloc + `delete` the same way (§3). Do **not** apply Turbofan/Maglev advice there.
4. On Node/Chrome, use §4 for elements kinds, IC polymorphism, and deopt checks — then measure.
5. For CLIs, lint/test runners, and package cold-start, use §5 (resolution, lazy `require`, barrels) — not the jp-* rules alone.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Allocation and shapes](#1-allocation-and-shapes)
- [2. `delete` and shape](#2-delete-and-shape)
- [3. Embed and 小程序](#3-embed-and-小程序)
- [4. V8 optimizations (Node / Chrome)](#4-v8-optimizations-node--chrome)
- [5. Startup and tooling (cold paths)](#5-startup-and-tooling-cold-paths)
- [Lint map](#lint-map)
- [References](#references)

---

## 0. Scope and method

1. **Shapes first** — initialize fields in one order; avoid polymorphic hot paths (§1, §4.1).
2. **Alloc pressure** — `.push({…})`, `new`, non-empty object binders; default scope reports these outside loops too (§1).
3. **`delete`** — prefer tombstones or parallel structures on hot objects (§2); avoid `delete arr[i]` holes (§4.2, jp-delete-array-hole).
4. **Embed** — same alloc/shape rules without assuming `window` / DOM or V8 tiers (§3).
5. **V8 Node/Chrome** — elements kinds, IC state, deopts, pipeline sketch (§4).
6. **Startup / tooling** — profile with `--cpu-prof`; cut FS/resolution; lazy-load rare paths; watch barrels (§5).
7. **Measure** — `--prof` / `--cpu-prof` / `--trace-deopt` / Performance panel / `examples/bench` before rewriting.

Sources: [XPerf playbook](../../../docs/playbook.md) · [corpus.md](corpus.md) · [Marvin series](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)

---

