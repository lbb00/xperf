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

**Evidence (this machine):** [`evidence/jp-alloc-in-loop`](../evidence/jp-alloc-in-loop.md) — `new Uint8Array` in-loop vs once **~19×**; `.push({i})` vs prealloc fill **~6.4×** (Node v20.19.2). Mechanism is alloc/GC (STATIC-VS-V8 PARTIAL for deopt). Default severity is **off** (`--preset all` or `--severity jp-alloc-in-loop=hint` enables it) — see [evidence-policy](evidence-policy.md). Default **`--scope all`** reports these patterns outside loops too; `--scope loop` keeps the former in-loop-only match.

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

