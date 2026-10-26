# zp-append-without-reserve — append-without-reserve

## Claim

ArrayList.append in loop vs ensureTotalCapacity + appendAssumeCapacity under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-append-without-reserve` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `append_no_reserve`
- **after:** `ensure_then_assume`
- ops=50000
- Raw: [`zp-append-without-reserve.jsonl`](zp-append-without-reserve.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~0.1308 ms |
| Median after | ~0.06291 ms |
| **ratio before/after** | **~2.08×** |

## Lint mapping

`zperf-lint` `zp-append-without-reserve` / `append-without-reserve`. Default severity in `rules.zig` is **off** (the CLI does not report the rule); see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~2.08× for N=50k growth from empty.

## Limits

When N is unknown, reserve may waste; test/arena paths are skipped by lint.
