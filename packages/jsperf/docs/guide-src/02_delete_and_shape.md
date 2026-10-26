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

