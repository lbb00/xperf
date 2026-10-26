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
2. **Alloc in loops** — `.push({…})`, `new` per iteration, non-empty object binders (§1).
3. **`delete`** — prefer tombstones or parallel structures on hot objects (§2); avoid `delete arr[i]` holes (§4.2, jp-delete-array-hole).
4. **Embed** — same alloc/shape rules without assuming `window` / DOM or V8 tiers (§3).
5. **V8 Node/Chrome** — elements kinds, IC state, deopts, pipeline sketch (§4).
6. **Startup / tooling** — profile with `--cpu-prof`; cut FS/resolution; lazy-load rare paths; watch barrels (§5).
7. **Measure** — `--prof` / `--cpu-prof` / `--trace-deopt` / Performance panel / `examples/bench` before rewriting.

Sources: [XPerf playbook](../../../docs/playbook.md) · [corpus.md](corpus.md) · [Marvin series](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)

---

## 1. Allocation and shapes

### 1.1 Hidden classes (shapes)

Engines (V8 and friends) assign a **hidden class** / map based on property addition order. Divergent shapes in a hot loop force polymorphic or megamorphic ICs.

- Initialize all fields in a consistent order (`return { x, y, z: 0 }`).
- Avoid `if` branches that add different properties first.
- See `examples/m01_hidden_class.js` (illustrative; no timing claim).

### 1.2 Allocation in loops (jp-alloc-in-loop)

Per-iteration allocation creates garbage and GC pauses when the loop is hot:

| Pattern | Lint? | Notes |
|---------|-------|-------|
| `.push({…})` / `.push([…])` | yes | Classic builder noise |
| Non-empty `{…}` / `[…]` binder in a loop | yes | Options bags that escape each iter |
| `new Ctor` / `Object.create` in a loop | yes (r2+) | Except `throw new` / `Error` / `ERR_*` |
| Empty `{}` / `[]` binder | **no** (r2) | Once-per-retry opts bags were noise on Node |
| `throw new …` | no | Error path |

Prefer typed arrays (`examples/p01_typed_array.js`), object pools, or preallocated structures **when profiles show GC time** — not by default on every `.push`.

**Evidence (this machine):** [`evidence/jp-alloc-in-loop`](../evidence/jp-alloc-in-loop.md) — `new Uint8Array` in-loop vs once **~19×**; `.push({i})` vs prealloc fill **~6.4×** (Node v20.19.2). Mechanism is alloc/GC (STATIC-VS-V8 PARTIAL for deopt). Default severity is **off** (`--preset all` or `--severity jp-alloc-in-loop=hint` enables it) — see [evidence-policy](evidence-policy.md).

### 1.3 Corpus dogfood (heuristic)

Counts below come from earlier line-window revisions of the linter (r1–r3) and show how the heuristics were narrowed; current corpus results are in [corpus.md](corpus.md).

| Corpus | r1 → r2 → r3 | Notes |
|--------|--------------|-------|
| Node `lib/` | 60 → 179 → **115** (jp-alloc-in-loop **33 → 158 → 94**; jp-delete-shape 27 → 21 → 21) | r2 intentional `new` / non-empty binders raised jp-alloc-in-loop; r3 comment/`for` FP cut it. Residual jp-alloc-in-loop: `inspect.js` `new SafeMap()` (~16), stream `pull.js` / `share.js` / `broadcast.js` `IterResult` / `Uint8Array`, `abort_controller.js` `??= new SafeSet()` inside a real `for` |
| Preact `src/` | **0 → 0 → 0** | Clean baseline — rules may be narrow for framework cores (little `.push({` / loop `new`) |
| quickjs `*.js` | 5 → 4 → **2** jp-alloc-in-loop | tests/ skipped; leftover codegen-ish scripts |
| TypeScript `packages/typescript/src` | — → 47 → **15** jp-alloc-in-loop | Post-Go-migration tip (~50 `.ts`); comment/loop fix helped. Classic `src/compiler` not in this tree |

**Reading Node residual:** once-init `??= new` inside a real loop is often **true** allocation (severity tier vs `.push({` still open). `inspect.js` SafeMap construction can be loop-adjacent without being per-element hot — review, do not mass-rewrite.

### 1.4 Reverse-opt that mattered

- Drop empty `{}`/`[]` binders (r2) — killed Node options-bag noise; kept `.push({`.
- Multi-line block comments + brace-less `for` fix (r3) — JSDoc `for` and `for (…)\n stmt;` no longer open fake loops (Console prototype install, etc.).
- Fixtures: `good/empty_opts_in_loop.js`, `good/comment_for_not_loop.js`, `good/throw_new_in_loop.js`, `good/jp-alloc-in-loop_reuse_buffer.js`, `bad/jp-alloc-in-loop_new_in_loop.js`, `bad/jp-alloc-in-loop_push_object.js`.

### 1.5 String `+=` in a loop (removed)

`jp-string-plus-in-loop` used to match `+=` of a string literal or `String.fromCharCode` and say to switch to `push` then `join`. That rewrite does not have about a 2× gain on the shapes the matcher hit (Node v24.18.0, V8 13.6.233.17-node.50).

| Shape | `+=` ms | `join` ms | `+=` / `join` |
| --- | ---: | ---: | ---: |
| `"\n"` × 100, repeated 200 | 0.194 | 0.126 | 1.53 |
| `"\n"` × 22000, repeated 20 | 1.648 | 2.756 | 0.60 |
| `"\n"` × 44000, repeated 10 | 1.459 | 3.176 | 0.46 |
| `String.fromCharCode` × 22000, repeated 10 | 0.893 | 2.647 | 0.34 |
| 64-character literal × 700, repeated 40 | 0.070 | 0.226 | 0.31 |
| `obj.s += "\n"` × 22000, repeated 10 | 0.759 | 1.816 | 0.42 |

A ratio near 2 would mean `join` is twice as fast. The 100-newline case is 1.53×, under that bar. At 22000 and 44000 characters, `join` is slower. V8 already builds the string for `+=` in a loop. `push` then `join` also allocates the pointer array. The matcher is deleted. Tombstone: [`jp-string-plus-in-loop`](../evidence/_removed/jp-string-plus-in-loop.REMOVED.md).

### 1.6 Chained `.map` / `.filter` (jp-map-filter-chain)

`.filter().map()` allocates an intermediate array on every call. The cost grows with the array length and with how many passes you make. A 3-element list and a 35000-row table are not the same cost.

On this machine (same Node as §1.5), both sides build the result array:

| Shape | chain ms | one pass ms | ratio |
| --- | ---: | ---: | ---: |
| 3 rows, filter then map, × 20000 | 0.289 | 0.226 | 1.28× |
| 3 rows, four filters then map, × 20000 | 0.761 | 0.220 | 3.46× |
| 35000 rows, filter then map, × 20 | 8.728 | 1.898 | 4.60× |
| 35000 rows, four filters then map, × 20 | 12.850 | 1.306 | 9.84× |

The 3-row filter-then-map case is under 2×. Four passes on 3 rows is above 2×, and 20000 calls still finish in under a millisecond. The 35000-row cases are where one pass is clearly faster. The hint names that length. Rewriting a short list is optional.

Lint: **jp-map-filter-chain** — default **hint**. `//` comments and block comments are stripped before the match. Codegen `gen-*.js` files are path-skipped. Evidence: [`jp-map-filter-chain`](../evidence/jp-map-filter-chain.md).

---

## 2. `delete` and shape

### 2.1 Why `delete` hurts on hot objects

`delete obj.key` changes the object’s hidden class. Engines may fall off monomorphic ICs; the hole can force dictionary mode on some paths. Prefer:

- `obj.key = undefined` / `null` when the field is optional and the shape should stay stable.
- A parallel `Set` / bitset / dense side table for “present?” when absence is common.
- Rebuild a new object in a cold path instead of deleting in a hot loop.

Lint: **jp-delete-shape** — `delete` on a member expression (file-level heuristic; not loop-only by default). Measured gate: [`evidence/jp-delete-shape`](../evidence/jp-delete-shape.md) (~**474×** vs tombstone on Node v20.19.2); the JSONL agrees, but corpus triage found the hits were almost all OK-idiom (see [evidence-policy](evidence-policy.md)), so the default is **off** (`--preset all` or `--severity jp-delete-shape=error` enables it).

### 2.2 Intentional `delete` (bootstrap / feature stripping)

Node’s `lib/internal/bootstrap/**` uses `delete` for module cache and feature stripping. That is startup / one-shot, not a per-request hot path.

**jsperf-lint:** skips files under `internal/bootstrap/`, filenames matching `*bootstrap*`, and inspect/debugger/test-runner paths for jp-delete-shape and jp-delete-array-hole.

**Evidence (dogfood):** Node `lib/` jp-delete-shape **27 → 21** after bootstrap skip (r1→r2); held at **21** in r3 while jp-alloc-in-loop moved. Remaining deletes need case-by-case review (CLI teardown, rare maps).

### 2.3 Optional future

`--hot-only` (require loop context for jp-delete-shape) is not shipped. Until then, treat jp-delete-shape outside loops as a shape smell, not an automatic bug.

---

## 3. Embed and 小程序

### 3.1 Same physics, smaller runtime

QuickJS, Hermes-like embeds, and 小程序 JS runtimes still pay for:

- Per-iteration object allocation (jp-alloc-in-loop patterns).
- Shape changes via `delete` or divergent property order.
- Logging in tight loops (**jp-console-in-loop** — `console.log` / `console.debug`). Evidence: [`jp-console-in-loop`](../evidence/jp-console-in-loop.md) (~**1300×** vs quiet even with discarded stdout) — default **off** (`app`) / **hint** (`engine`), not a CI error.

They often **lack** a browser Performance panel, DOM, or large IC budgets. Advice that starts with “open DevTools → …” does not transfer. Prefer:

- Alloc/shape discipline from §1–§2.
- Batching work (`examples/p02_batch_note.js`) instead of per-item microtasks when the host exposes a batch API.
- Measuring with the **host** profiler (Node `--prof`, QuickJS timing hooks, vendor 小程序 perf panels) — not Chrome-only workflows.

**Do not** apply §4 (Maglev/Turbofan, elements-kind transitions, `--trace-deopt`) to these runtimes. Stable shapes and fewer allocs still help; V8 tier talk does not.

### 3.2 Shared quickjs tree

cperf dogfoods the **C** engine; jsperf dogfoods the `*.js` beside it (tests and `gen-*` skipped). The current rules report **0** findings there ([corpus.md](corpus.md)); earlier revisions reported 2 jp-alloc-in-loop. Low pressure, but useful as an embed-adjacent sample. Do not expect Preact-level cleanliness on generator scripts.

### 3.3 What not to recommend here

- DOM batching / `requestAnimationFrame` as the primary fix.
- `innerHTML` vs `createElement` debates.
- Browser-only APIs (`WeakRef` + FinalizationRegistry patterns that the embed may not ship).
- Turbofan / Maglev / elements-kind tuning from §4.

Typed arrays and consistent shapes remain portable (`examples/p01_typed_array.js`, `m01_hidden_class.js`).

---

## 4. V8 optimizations (Node / Chrome)

This chapter deepens §1 for **V8** specifically. It does **not** apply to QuickJS, Hermes-like embeds, or 小程序 runtimes — see §3. Those engines share “stable shapes / fewer allocs” physics; they do **not** get Ignition → Maglev/Turbofan advice, elements-kind transitions, or `--trace-deopt` workflows.

Dated as a **Node 22+ / modern V8 continuum** (measured on Node v22.22.3, V8 12.4.x). Pipeline tier names and flags drift; treat version pins below as “what we ran,” not forever guarantees.

### 4.1 Hidden classes / maps and ICs (extends §1.1)

V8 attaches a **map** (hidden class) to each object. Property addition order and type feedback build a transition tree. Property loads/stores go through **inline caches (ICs)**:

| IC state | Meaning (practical) |
|----------|---------------------|
| Monomorphic | One map seen — best case for a hot load/store |
| Polymorphic | A few maps (small fixed set) — still optimizable, slower |
| Megamorphic | Many maps — IC gives up; generic slow path |

**Do:** construct with one field order (`{ x, y, z: 0 }`); keep hot call sites on one shape. **Don’t:** branch so some objects get `x` before `y` and others the reverse; don’t `delete` fields on hot objects (§2).

Microbench: `examples/bench/shape_mono_vs_poly.js` (same-order vs divergent constructors; numbers in §4.6).

### 4.2 Elements kinds

Arrays are not one representation. V8 tracks **elements kinds**, roughly:

| Kind (concept) | Typical contents |
|----------------|------------------|
| `PACKED_SMI_ELEMENTS` | Dense small integers, no holes |
| `PACKED_DOUBLE_ELEMENTS` | Dense floats (after a non-Smi number appears) |
| `PACKED_ELEMENTS` | Dense object/value mix |
| `HOLEY_*` | Same families **with holes** (missing indices) |

**Practical dos/don’ts:**

- Prefer dense `push` / preallocate (`new Array(n)` then fill 0..n-1) over sparse writes.
- **Don’t punch holes:** `delete arr[i]`, or skip indices (`arr[0]=1; arr[2]=2`), forces holey kinds and weaker optimized code.
- For numeric hot loops, prefer **typed arrays** (`Float64Array`, `Uint32Array`, …): fixed element type, no holey transition, contiguous storage. Ordinary `number[]` can stay packed, but mixed Smi/double transitions and boxing still cost.
- Reading past `length` or relying on holes as “optional slots” is a shape smell; use a parallel length, a typed bitmask, or `undefined` tombstones on a **packed** array if you must.

Lint: **jp-delete-array-hole** flags `delete arr[i]`-style member deletes (holey risk); measured gate [`evidence/jp-delete-array-hole`](../evidence/jp-delete-array-hole.md) (~**3.2×**). jp-delete-shape covers `delete obj.key` on ordinary members; it historically missed computed index deletes — jp-delete-array-hole closes that gap.

Microbenches: `examples/bench/elements_packed_vs_holey.js`, `examples/bench/typed_array_vs_number_array.js`.

### 4.3 Deopts — when they matter; how to check

A **deopt** throws optimized code back to a slower tier because assumptions broke (unexpected map, elements kind, bounds, etc.). Occasional deopts at startup or on rare paths are normal. Deopts **matter** when they sit on a profiled hot function and repeat every iteration.

**Static jsperf-lint cannot detect JIT outcomes.** IC state, deopt, and optimization tier are runtime facts. The jp-* rules only flag allocation/shape *smells*. JIT verification = profile / `--trace-deopt` / bench — never “the linter said so.”

**Runtime harness (not a lint rule):**

```sh
# Preferred across Node versions:
node --trace-deopt examples/bench/deopt_probe.js
bash scripts/jit-check.sh   # writes examples/bench/out/deopt-sample.txt

# Optional / fragile: V8 natives (status codes drift)
USE_NATIVES=1 node --allow-natives-syntax --trace-deopt examples/bench/deopt_probe.js
```

On this machine (Node v22.22.3), `deopt_probe` warmed `hotLoad` monomorphic then fed divergent maps; `--trace-deopt` reported:

`[bailout … reason: wrong map … JSFunction hotLoad … Code TURBOFAN]`

One-shot `-e` scripts often also print “Insufficient type feedback …” — treat that as **startup noise**, not proof your smell is hot.

**Check (Chrome):** Performance panel → V8 markers where available; correlate with wall-clock before/after. No fake speedup percentages.

### 4.4 Pipeline sketch (Ignition → Maglev / Turbofan)

High level, modern V8/Node:

1. **Ignition** — bytecode interpreter; gathers type feedback.
2. **Maglev** — mid-tier optimizing compiler (present on current Node 22+ / recent V8 builds; exact enablement can depend on flags and workload).
3. **Turbofan** — top-tier optimizing compiler for hot code.

Code may climb tiers as it heats up and fall back on deopt. **Do not** overclaim “always Maglev on Node N” or pin exact tier thresholds — they move. For embeds without this pipeline (§3), skip tier talk entirely.

### 4.5 What jsperf-lint can and cannot see

**Hard limit:** the static jp-* rules **cannot** recognize JIT optimization success/failure. No rule observes monomorphic vs mega ICs, Maglev/Turbofan tier, or deopt.

| Rule | Sees | Does **not** see |
|------|------|------------------|
| jp-alloc-in-loop | Loop-adjacent `.push({`, non-empty binders, clear `new` containers | IC polymorphism; whether alloc causes deopt (usually it does not — it causes GC) |
| jp-console-in-loop | `console.*` in a loop window | Whether logging is actually hot |
| jp-delete-shape | `delete obj.key`-style members | Dictionary mode already; deopt vs “just slow” |
| jp-delete-array-hole | `delete arr[i]` (holey) | Runtime elements kind; holey from skipped indices without `delete` |
| jp-string-plus-in-loop | removed | `push` + `join` was not about 2× on the matched `+=` shapes |
| jp-map-filter-chain | chained `.map` / `.filter` / `.flatMap` on one line | Array length; a 3-row chain and a 35000-row chain are different costs |

Lint = allocation/shape smells. JIT verification = `jit-check.sh` / `--trace-deopt` / `examples/bench`. Polymorphic ICs leave **no** jp-* fingerprint.

### 4.6 Measured on this machine (Node v22.22.3)

Ran 2026-10-21 18:49 Asia/Shanghai via `scripts/run-v8-benches.sh` → `examples/bench/out/`. Node **v22.22.3**, V8 **12.4.254.21-node.56**, linux x64. Warm-up 3 + 9 rounds; medians below. **Single-machine numbers only** — not a cross-machine claim.

| Bench | Variant | N | Median ms | Ops/s (approx.) |
|-------|---------|---|-----------|-----------------|
| shape_mono_vs_poly | mono (same field order) | 2e5 | **0.219** | ~9.1e8 |
| shape_mono_vs_poly | poly (divergent order) | 2e5 | **1.435** | ~1.4e8 |
| elements_packed_vs_holey | packed fill+sum | 2e5 | **1.227** | ~1.6e8 |
| elements_packed_vs_holey | holey via `delete` | 2e5 | **4.589** | ~4.4e7 |
| elements_packed_vs_holey | holey via skipped index | 2e5 | **1.445** | ~1.4e8 |
| typed_array_vs_number_array | dense `number[]` fill+sum | 1e6 | **5.217** | ~1.9e8 |
| typed_array_vs_number_array | `Float64Array` fill+sum | 1e6 | **5.948** | ~1.7e8 |

**Reading:** poly shapes ~**6.5×** slower than mono here; `delete`-holey ~**3.7×** slower than packed. Skipped-index holey writes fewer slots — compare kind behavior, not raw speed alone. On this dense-double workload `number[]` was **slightly faster** than `Float64Array`; typed arrays still matter for fixed element types, avoiding packed→holey / Smi→double transitions, and binary/WASM boundaries — measure your loop.

Full JSONL: `examples/bench/out/results.jsonl` (written by the script).

### 4.7 Correlation: static smell vs V8 time (PARTIAL)

Experiment: `examples/bench/static_vs_v8_correlate.js` · `scripts/run-static-vs-v8.sh` (Node **v22.22.3**).

| Case | Static smell? | Ratio (smell/clean) | Agree? |
|------|---------------|---------------------|--------|
| Mono vs poly shapes | poly only | **12.0×** | **YES** (+ `wrong map` deopt on mono→poly) |
| Packed vs holey `delete a[i]` | jp-delete-array-hole-like | **5.47×** | **YES** (time); deopt noisy |
| `Float64Array` vs holey `number[]` | holey | **1.34×** | **PARTIAL** (muted) |
| `delete obj.k` vs `= undefined` | jp-delete-shape | **165×** | **YES** (time); deopt counts alike |
| Control: `new` in loop vs once | jp-alloc-in-loop | **49.3×** | **PARTIAL** — alloc/GC pain, not deopt |

**Do not pretend the jp-* rules equal JIT awareness.** Agreement is strongest for shapes / holey / hot `delete`; weakest when using deopt line counts as an oracle or when selling typed arrays as always faster than packed doubles.

**JSONL gates (Node v20.19.2 on this machine, re-run `scripts/regen-evidence.sh`):** jp-delete-array-hole ~**3.2×** → **error**; jp-delete-shape ~**474×** (corpus hits almost all OK-idiom) → **off**; jp-alloc-in-loop ~**19×** (alloc/GC) → **off**; jp-console-in-loop ~**1328×** (discard sink, env-dependent) → **off** (`app`) / **hint** (`engine`). See [`evidence-policy`](evidence-policy.md) and `evidence/jp-*.md`.

---

## 5. Startup and tooling (cold paths)

This chapter is about **tooling / cold-start / module-graph** cost — not the hot-loop shape and allocation smells in §1–§2 / §4.

Primary source: Marvin Hagemeister’s series **[Speeding up the JavaScript ecosystem](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)** (parts 1–13). Methods below are paraphrased; **do not treat his wall-clock numbers as ours** — re-measure on your machine.

| Concern | Chapters | What finds it |
|---------|----------|---------------|
| Runtime shape / alloc / holey / `delete` | §1, §2, §4 | the jp-* rules + `examples/bench` |
| Module resolution, eager `require`, barrels, CLI overhead | **§5** | `node --cpu-prof` / speedscope, require-graph inspection — **not** the jp-* rules |

### 5.1 Profile first (tooling)

Before rewriting a library or CLI:

1. Capture a CPU profile: `node --cpu-prof your-tool.js …` (or `node --cpu-prof $(which npm) run …` for npm scripts — see [part 4](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-4/)).
2. Open the `.cpuprofile` in [speedscope](https://www.speedscope.app/) (or Chrome DevTools).
3. Ask: is time in **your** hot function, or in **loading / resolving** modules, casting, regex, FS?

Marvin’s recurring method ([part 1](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)): find a top frame → open source → remove avoidable work → re-profile. Same loop as XPerf’s “measure before rewrite,” aimed at **build/lint/CLI** rather than app render loops.

### 5.2 Hot casts, short-string regex, inner functions (part 1 methods)

Paraphrased patterns from [part 1](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/) (PostCSS, SVGO, and neighbors):

- **String ↔ number churn** — e.g. `toFixed` then `+` back to number in a tight loop. Prefer staying in number-land (`Math.round` / scale by `10**p`).
- **Regex on many short strings** — matching one regex against many tiny serialized fragments is often worse than one pass over a longer string, or a cheap pre-check that the needle exists at all.
- **Functions created inside hot outer functions** — closures recreated every call hurt ICs; lift helpers or pass args explicitly instead of capturing.
- **Transpiler artifacts** — e.g. `for…of` rewritten into a fresh `_loop` function per iteration; inspect **published** output, not only source.

These can overlap §4 (ICs) when the path is hot at runtime. In tooling they often dominate **startup or per-file** cost instead.

### 5.3 Module resolution (part 2 methods)

From [part 2](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-2/): resolution can outweigh parsing in lint/test/build traces.

Adopt as checklist (paraphrase of his four takeaways):

1. **Avoid FS** — every `stat`/`exists` is expensive at scale.
2. **Cache** resolved paths (watch mode: invalidate carefully).
3. **`fs.statSync(path, { throwIfNoEntry: false })`** — avoid throwing + capturing stack traces for “file missing” (ENOENT path).
4. **Limit upward `node_modules` walks** — especially when path aliases are mistaken for bare package imports.

Also watch **extension guessing** (`.js` → `.jsx` → … → `.ts`) and alias plugins that do not share the same resolver as TypeScript/`tsconfig` paths.

**jsperf-lint cannot see this.** No jp-* rule measures FS or resolution. Companions: CPU profiles, resolver caches, and the eager-vs-lazy sketch in `examples/bench/require_cost_sketch.js`.

### 5.4 Startup: eager graph, barrels, “gorilla holding a banana”

From [part 4](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-4/) (npm scripts) and [part 7](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-7/) (barrels):

- **Eager `require` / `import`** loads the whole reachable graph up front. Error formatters, audit code, progress bars — anything unused on the happy path — should be **lazy** (`require` inside the `if (err)` branch, dynamic `import()` for rare commands).
- **Fat classes / mixin piles** pull “the gorilla holding the banana and the entire jungle” (Joe Armstrong, via Marvin): one entry class that mixins audit + reify + rebuild when you only needed `run`.
- **Barrel files** (`index.js` that only `export * from …`) amplify the graph: one import can pull a folder tree; test runners that spawn per file pay the cost repeatedly. Prefer direct imports when startup or lint/test wall time matters.
- **Published bundle** for CLIs can shrink load cost; measure — giant single files have a parse tradeoff.

### 5.5 Relation to the jp-* rules

| | Runtime chapters (§1–§2, §4) | This chapter (§5) |
|--|----------------------------|-------------------|
| Typical win | Hot loop IC / GC / elements kind | Cold start, `npm run`, lint/test graph |
| Lint | the jp-* rules (line-window heuristics) | **None today** — document-only companions |
| Evidence | `examples/bench/*`, `--trace-deopt` | `--cpu-prof` + speedscope; require-graph size |

Do **not** interpret a clean jsperf-lint self-lint as “startup is fine.” Do **not** treat Marvin’s published speedups as transferable without a local profile.

### 5.6 Optional sketch: eager vs lazy require

`examples/bench/require_cost_sketch.js` builds a tiny fixture graph and times eager top-level `require` vs lazy `require` inside a rarely taken branch. It is a **teaching microbench**, not a claim about npm or your app. Run: `node examples/bench/require_cost_sketch.js`.

---

## 6. Constructors, JSON, DOM queries, and date formats

Each hint below is one measured shape. The hint line states that premise. A call that only looks similar is not given that rewrite.

`new RegExp(pattern)` compiles on every call when the pattern stays the same. A regex literal is cached. If the pattern is the loop variable, or `parts[i]`, the checker does not say to compile once. The bench compiled one fixed pattern, about 4.4× on Node 26.

`JSON.parse` of one unchanged text was about 140× on Node 26 versus parsing once. `JSON.stringify` of an unchanged value is the same shape. A JSONL line, or `rows[i]`, is a different text every iteration. The checker skips an argument that is the loop binding. It does not tell you to fold those lines into one parse.

`querySelector` / `getElementById` of one unchanged selector was about 16× on Node 26, a tiny linkedom document. A selector built from the loop index is not that bench. `new Intl.DateTimeFormat` with unchanged locale and options was about 36× on Node 26; both sides still format. `new Date` is not this rule.

`fs.readFileSync` of one unchanged path, inside the loop body, was about 114× on Node 26 versus reading once. `for (const line of readFileSync(file).split("\n"))` runs the read once, before `{`. The checker reports the call only in the body. A path that changes every iteration cannot be hoisted. A `while (readFileSync(path))` condition is outside the body and is not reported.

`Date.now` was about 26× and `performance.now` about 19× versus one sample, in a tight loop that did not wait. A loop that contains `await`, or a `for await` loop, is not reported. Hoist the clock only when that iteration does not need a fresh time. A rate limiter that reads the clock each pass has nothing to move.

**jp-regex-ctor-in-loop** and **jp-json-in-loop** stay **hint** on the app and engine presets. JSONL exists for those two, and the 2026-10-22 verdict does not cover them. **jp-dom-query-in-loop** (about 16× on Node 26, a tiny linkedom document) and **jp-intl-datetimeformat-in-loop** (about 36× on Node 26, both sides still format) have JSONL and stay **hint**. They are outside that verdict. `--preset all` is error for every rule that still exists.

`Reflect.get` was about 8× and was not given a rule.

Companion lint: **jp-regex-ctor-in-loop**, **jp-json-in-loop**, **jp-dom-query-in-loop**, **jp-intl-datetimeformat-in-loop**, **jp-readfile-sync-in-loop**, **jp-clock-in-loop**.
### Lint map

| ID | Topic | Severity | Evidence / note |
|----|--------|----------|-----------------|
| jp-alloc-in-loop | object/array/`new` alloc in loop | **off** (`all`: error) | [`jp-alloc-in-loop`](../evidence/jp-alloc-in-loop.md) ~19× / ~6.4× — GC/alloc, not deopt |
| jp-console-in-loop | `console.*` in loop | **hint** (`engine`) / **off** (`app`) | [`jp-console-in-loop`](../evidence/jp-console-in-loop.md) ~1328× discard sink — env-dependent |
| jp-delete-shape | `delete` on plain members | **off** (`all`: error) | [`jp-delete-shape`](../evidence/jp-delete-shape.md) ~474× vs tombstone; corpus hits almost all OK-idiom |
| jp-delete-array-hole | `delete` with computed index (holey arrays) | **error** | [`jp-delete-array-hole`](../evidence/jp-delete-array-hole.md) ~3.2× vs packed |
| jp-map-filter-chain | chained `.map` / `.filter` / `.flatMap` | **hint** | long arrays about 4.6×–9.8×; a 3-row filter+map is 1.28× |
| jp-regex-ctor-in-loop | `new RegExp` in loop, pattern not a loop binding | **hint** | Node 26 fixed pattern about 4.4×; hoist only when it stays the same |
| jp-json-in-loop | `JSON.parse` / `stringify` in loop, text not a loop binding | **hint** | Node 26 one unchanged text about 140×; hoist only when it stays the same |
| jp-dom-query-in-loop | DOM query in loop | **hint** | JSONL about 16× on Node 26, a tiny linkedom document; not corpus-triaged |
| jp-intl-datetimeformat-in-loop | `new Intl.DateTimeFormat` in loop | **hint** | Node 26 about 36×; both sides still format; not corpus-triaged |
| jp-readfile-sync-in-loop | `readFileSync` in the loop body | **hint** | Node 26, one unchanged path about 114×; the `for` iterable runs once and is not reported |
| jp-clock-in-loop | `Date.now` / `performance.now` in a tight loop | **hint** | Node 26 about 70× / 110× with no `await`; hoist only when this pass does not need a fresh time |
| *(none)* | module resolution / eager graph / barrels | — | §5 — use `--cpu-prof` |

Severities above are the default `app` preset. Policy: [`evidence-policy.md`](evidence-policy.md). Fixtures: `jsperf-lint/fixtures/{bad,good}/`.

### References

- [corpus.md](corpus.md)
- `examples/bench/` · `scripts/run-v8-benches.sh` · `scripts/jit-check.sh` · `scripts/run-static-vs-v8.sh` · `scripts/regen-evidence.sh` · `examples/bench/require_cost_sketch.js`
- [XPerf playbook](../../../docs/playbook.md)
- Marvin Hagemeister — [Speeding up the JavaScript ecosystem](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/) (parts 1–13; methods cited in §5)
