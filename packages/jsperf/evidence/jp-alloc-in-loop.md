# jp-alloc-in-loop — allocation-like patterns in loops

## Claim

Hot per-iteration allocation (`new` of clear containers/buffers, `.push({…})`) is slower than reuse / preallocation on V8/Node, primarily via **alloc/GC cost**, not via deopt/IC failure.

## How measured

- Harness: `packages/jsperf/examples/bench/evidence_jp001_jp002.js`
- Pair A (matches `static_vs_v8_correlate.js` case 5): N=200000; warm=3; median of 9
  - **before:** `new Uint8Array(16)` inside the loop
  - **after:** one `Uint8Array` outside; mutate in loop
- Pair B: N=200000
  - **before:** `.push({ i })` builder
  - **after:** `new Array(N)` fill + sum (semantics differ — speed oracle only)
- Raw lines: [`jp-alloc-in-loop.jsonl`](jp-alloc-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (local clock; ISO ts in JSONL is UTC) |
| Node | **v20.19.2** |
| V8 | **11.3.244.8-node.38** |
| Median before (`new_in_loop`) | ~4.66 ms |
| Median after (`new_once_outside`) | ~0.24 ms |
| **ratio new_in_loop / once** | **~19×** |
| Median before (`push_object_literal`) | ~10.9 ms |
| Median after (`prealloc_fill_sum`) | ~1.69 ms |
| **ratio push / prealloc** | **~6.4×** |

Earlier correlation on Node v22.22.3 / V8 12.4 showed ~**49×** for the Uint8Array pair (`scripts/run-static-vs-v8.sh`). Direction stable; magnitude Node/machine-sensitive.

## Lint mapping

`jsperf-lint` jp-alloc-in-loop flags `.push({` / non-empty binders / clear `new` / `Object.create` in a loop window. Default severity is **`off`** under [evidence-policy](../docs/evidence-policy.md) (`--preset all` or `--severity jp-alloc-in-loop=hint` enables it): wall-clock agrees, but the mechanism is GC/alloc — **not** a JIT/deopt gate — and residual Node `lib/` hits need human review (SafeMap, once-init, streams).

## Limits

- Microbench; not an app profile.
- Pair B changes result shape (objects vs ints) — use only as “builder tax” illustration.
- Do **not** equate jp-alloc-in-loop with deopt/IC failure (STATIC-VS-V8 case 5).
- Marvin §05 (startup/tooling) is out of band for this runtime gate.
