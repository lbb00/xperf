# jp-delete-shape — `delete` on plain members

## Claim

Hot `delete obj.key` is slower than keeping the shape with a tombstone (`obj.key = undefined`) on V8/Node, because `delete` transitions the object map / can force dictionary-mode paths.

## How measured

- Harness: `packages/jsperf/examples/bench/evidence_jp003_jp004.js` (same kernels as `static_vs_v8_correlate.js` case 4)
- Work: N=200000 iterations; warm=3; median of 9 `process.hrtime.bigint` samples
- **before:** construct `{ k, keep }`, `delete o.k`, touch fields
- **after:** same construct, `o.k = undefined`, touch fields
- Raw lines: [`jp-delete-shape.jsonl`](jp-delete-shape.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (local clock; ISO ts in JSONL is UTC) |
| Node | **v20.19.2** |
| V8 | **11.3.244.8-node.38** |
| Median before (`delete_obj_k`) | ~43.2 ms |
| Median after (`tombstone_undefined`) | ~0.091 ms |
| **ratio before/after** | **~474×** |

Earlier correlation on Node v22.22.3 / V8 12.4 showed ~165× in the same direction (`scripts/run-static-vs-v8.sh`). Prior gate on this machine was ~360×. Direction is stable; magnitude is machine/Node-sensitive — re-run the harness after upgrades.

## Lint mapping

`jsperf-lint` jp-delete-shape fires on `delete obj.key`-style members (not `delete arr[i]` — that is jp-delete-array-hole). Default severity is **`off`** under [evidence-policy](../docs/evidence-policy.md): this JSONL exists and agrees, but corpus triage found the hits almost all OK-idiom. `--preset all` or `--severity jp-delete-shape=error` enables it.

## Limits

- Microbench, not app profile.
- One-shot scripts: `--trace-deopt` line counts are a weak oracle (wall clock is the gate).
- Cold / bootstrap `delete` (Node `internal/bootstrap/**`) is skipped by the linter and out of scope for this claim.
