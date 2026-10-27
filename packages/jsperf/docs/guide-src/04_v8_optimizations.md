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
| jp-alloc-hot | `.push({`, non-empty binders, clear `new` containers (default scope all) | IC polymorphism; whether alloc causes deopt (usually it does not — it causes GC) |
| jp-console-hot | `console.*` (default scope all) | Whether logging is worth gating even off a hot path |
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
| Control: `new` in loop vs once | jp-alloc-hot | **49.3×** | **PARTIAL** — alloc/GC pain, not deopt |

**Do not pretend the jp-* rules equal JIT awareness.** Agreement is strongest for shapes / holey / hot `delete`; weakest when using deopt line counts as an oracle or when selling typed arrays as always faster than packed doubles.

**JSONL gates (Node v20.19.2 on this machine, re-run `scripts/regen-evidence.sh`):** jp-delete-array-hole ~**3.2×** → **error**; jp-delete-shape ~**474×** (corpus hits almost all OK-idiom) → **off**; jp-alloc-hot ~**19×** (alloc/GC) → **off**; jp-console-hot ~**1328×** (discard sink, env-dependent) → **off** (`app`) / **hint** (`engine`). See [`evidence-policy`](evidence-policy.md) and `evidence/jp-*.md`.

---

