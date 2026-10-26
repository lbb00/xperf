# zp-extern-struct-padding — extern-struct-padding

## Claim

Walk hot u64 fields of padded vs alignment-sorted extern structs under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-extern-struct-padding` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `extern_padded_walk`
- **after:** `extern_packed_walk`
- ops=2000000
- Raw: [`zp-extern-struct-padding.jsonl`](zp-extern-struct-padding.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~2.594 ms |
| Median after | ~2.147 ms |
| **ratio before/after** | **~1.21×** |

## Lint mapping

`zperf-lint` `zp-extern-struct-padding` / `extern-struct-padding`. Default severity in `rules.zig` is **off** (the CLI does not report the rule); see [evidence-policy](../../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~1.21× bandwidth for this shape (24B→16B class); modest.

## Limits

ABI-locked layouts must ignore; only when all field sizes known.
