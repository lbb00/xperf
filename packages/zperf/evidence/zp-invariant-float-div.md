# zp-invariant-float-div — invariant-float-div

## Claim

float / loop-invariant vs multiply by reciprocal under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-invariant-float-div` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `float_div_loop`
- **after:** `mul_reciprocal`
- ops=2000000
- Raw: [`zp-invariant-float-div.jsonl`](zp-invariant-float-div.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~2.504 ms |
| Median after | ~1.25 ms |
| **ratio before/after** | **~2×** |

## Lint mapping

`zperf-lint` `zp-invariant-float-div` / `invariant-float-div`. Default severity in `rules.zig` is **hint**; see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~2.00× without fast-math (ReleaseFast does not enable it).

## Limits

Rounding differs slightly; validate numerics.
