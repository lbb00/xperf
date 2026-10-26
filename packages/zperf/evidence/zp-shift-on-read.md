# zp-shift-on-read — shift-on-read

## Claim

copyForwards compact after prefix consume vs cursor head under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-shift-on-read` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `copy_forwards_consume`
- **after:** `cursor_head`
- ops=20000
- Raw: [`zp-shift-on-read.jsonl`](zp-shift-on-read.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~0.2825 ms |
| Median after | ~0.01686 ms |
| **ratio before/after** | **~16.8×** |

## Lint mapping

`zperf-lint` `zp-shift-on-read` / `shift-on-read`. Default severity in `rules.zig` is **warning**; see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~16.8× when repeatedly sliding remaining bytes.

## Limits

Amortize with read cursor; compact only when needed.
