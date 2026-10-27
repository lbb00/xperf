# zp-create-destroy-hot — create-destroy-in-loop

## Claim

Allocator.create/destroy(Node) vs MemoryPool under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-create-destroy-hot` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `create_destroy_loop`
- **after:** `memory_pool`
- ops=200000
- Raw: [`zp-create-destroy-hot.jsonl`](zp-create-destroy-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~4.026 ms |
| Median after | ~0.375 ms |
| **ratio before/after** | **~10.7×** |

## Lint mapping

`zperf-lint` `zp-create-destroy-hot` / `create-destroy-in-loop`. Default severity in `rules.zig` is **info**; see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~10.7× for fixed-size Node churn.

## Limits

Variable-size objects need other pools.
