# zp-map-put-without-ensure — map-put-without-ensure

## Claim

AutoHashMap.put growing from empty vs ensureTotalCapacity then put under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-map-put-without-ensure` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `map_put_grow`
- **after:** `map_ensure_then_put`
- ops=20000
- Raw: [`zp-map-put-without-ensure.jsonl`](zp-map-put-without-ensure.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~0.8296 ms |
| Median after | ~0.3001 ms |
| **ratio before/after** | **~2.76×** |

## Lint mapping

`zperf-lint` `zp-map-put-without-ensure` / `map-put-without-ensure`. Default severity in `rules.zig` is **off** (the CLI does not report the rule); see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~2.76× for N=20k inserts.

## Limits

Unknown final size: ensureUnusedCapacity in batches.
