# zp-bool-array — bool-array

## Claim

[]bool count vs bit_set.Static.count under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-bool-array` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `bool_array_count`
- **after:** `bitset_count`
- ops=524288
- Raw: [`zp-bool-array.jsonl`](zp-bool-array.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~0.08908 ms |
| Median after | ~0.002937 ms |
| **ratio before/after** | **~30.3×** |

## Lint mapping

`zperf-lint` `zp-bool-array` / `bool-array`. Default severity in `rules.zig` is **off** (the CLI does not report the rule); see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~30.3× for popcount-style walk (and 8× denser).

## Limits

Per-element addressability / concurrent bit writes may need []bool.
