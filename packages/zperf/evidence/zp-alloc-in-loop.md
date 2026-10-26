# zp-alloc-in-loop — alloc-in-loop

## Claim

GPA alloc+free each iteration vs ArenaAllocator.reset(.retain_capacity) under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-alloc-in-loop` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `gpa_alloc_free_in_loop`
- **after:** `arena_retain_in_loop`
- ops=100000
- Raw: [`zp-alloc-in-loop.jsonl`](zp-alloc-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~2.012 ms |
| Median after | ~1.422 ms |
| **ratio before/after** | **~1.41×** |

## Lint mapping

`zperf-lint` `zp-alloc-in-loop` / `alloc-in-loop`. Default severity in `rules.zig` is **off** (the CLI does not report the rule); see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~1.41× but modest on smp_allocator; FBA/pool (zp-fixed-size-alloc-in-loop) often larger. Direction clear.

## Limits

Hot path with tiny fixed sizes may prefer MemoryPool/FBA; arena retain is one valid fix.
