# zp-aos-single-field — aos-single-field

## Claim

AoS sum one field vs parallel []u32 SoA under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-aos-single-field` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `aos_sum_hp`
- **after:** `soa_sum_hp`
- ops=4000000
- Raw: [`zp-aos-single-field.jsonl`](zp-aos-single-field.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~4.801 ms |
| Median after | ~0.731 ms |
| **ratio before/after** | **~6.57×** |

## Lint mapping

`zperf-lint` `zp-aos-single-field` / `aos-single-field`. Default severity in `rules.zig` is **off** (the CLI does not report the rule); see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~6.57× when only one field is hot (fat Element).

## Limits

Other loops may touch all fields — lint is a review hint.
