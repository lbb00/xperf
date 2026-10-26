# zp-fixed-size-alloc-in-loop — fixed-size-alloc-in-loop

## Claim

GPA alloc+free 256B vs warm buffer-pool hit under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-fixed-size-alloc-in-loop` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `fixed_alloc_free_loop`
- **after:** `buffer_pool_hit`
- ops=100000
- Raw: [`zp-fixed-size-alloc-in-loop.jsonl`](zp-fixed-size-alloc-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~2.001 ms |
| Median after | ~0.236 ms |
| **ratio before/after** | **~8.48×** |

## Lint mapping

`zperf-lint` `zp-fixed-size-alloc-in-loop` / `fixed-size-alloc-in-loop`. Default severity in `rules.zig` is **info**; see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~8.5× (aligns with p20 pool vs GPA).

## Limits

Pool miss still hits GPA; size-class pools matter.
