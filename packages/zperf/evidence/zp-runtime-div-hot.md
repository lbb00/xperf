# zp-runtime-div-hot — runtime-div-in-loop

## Claim

i % runtime_pow2 vs i & (n-1) under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-runtime-div-hot` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `runtime_mod`
- **after:** `bitmask`
- ops=2000000
- Raw: [`zp-runtime-div-hot.jsonl`](zp-runtime-div-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~3.777 ms |
| Median after | ~0.3242 ms |
| **ratio before/after** | **~11.6×** |

## Lint mapping

`zperf-lint` `zp-runtime-div-hot` / `runtime-div-in-loop`. Default severity in `rules.zig` is **off** (the CLI does not report the rule); see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~11.6× for power-of-two modulus.

## Limits

Crypto/compiler_rt paths skipped; non-pow2 needs other rewrites.
