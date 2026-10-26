# jp-delete-array-hole — `delete arr[i]` (holey arrays)

## Claim

Using `delete a[i]` on a packed array creates a **holey** elements kind; a subsequent dense-style sum is slower than keeping a packed array on V8/Node.

## How measured

- Harness: `packages/jsperf/examples/bench/evidence_jp003_jp004.js` (same kernels as `static_vs_v8_correlate.js` case 2)
- Work: N=200000; warm=3; median of 9 rounds
- **before:** fill packed, `delete a[i]` for even i, sum defined slots
- **after:** fill packed, sum all slots (no delete)
- Raw lines: [`jp-delete-array-hole.jsonl`](jp-delete-array-hole.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai |
| Node | **v20.19.2** |
| V8 | **11.3.244.8-node.38** |
| Median before (`holey_delete_arr_i`) | ~5.14 ms |
| Median after (`packed_fill_sum`) | ~1.63 ms |
| **ratio before/after** | **~3.2×** |

Node v22.22.3 correlation previously saw ~5.5× in the same direction. Prefer re-measure on your Node before quoting a single factor.

## Lint mapping

jp-delete-array-hole flags `delete` with a computed index (`arr[i]`). Severity **error** under [evidence-policy](../docs/evidence-policy.md).

## Limits

- Fill+sum microbench; real apps may prefer `splice` / filter / dense tombstones for semantics, not only speed.
- Holey arrays can also arise from skipped indices without `delete` — lint will not see those.
- Deopt traces for this case are noisy; the gate is wall-clock ratio.
