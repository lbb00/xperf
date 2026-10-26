# zp-arena-reset-free-all — arena-reset-free-all

## Claim

ArenaAllocator.reset(.free_all) each iter vs .retain_capacity under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-arena-reset-free-all` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `arena_reset_free_all`
- **after:** `arena_reset_retain`
- ops=50000
- Raw: [`zp-arena-reset-free-all.jsonl`](zp-arena-reset-free-all.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~2.252 ms |
| Median after | ~0.7083 ms |
| **ratio before/after** | **~3.18×** |

## Lint mapping

`zperf-lint` `zp-arena-reset-free-all` / `arena-reset-free-all`. Default severity in `rules.zig` is **warning**; see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~3.18× — free_all returns pages every time.

## Limits

Use free_all when RSS must drop; retain for hot reuse.
