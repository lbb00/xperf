# zp-unbuffered-io — unbuffered-io

## Claim

Writer empty buffer (&{{}}) vs 4KiB buffer to /dev/null under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-unbuffered-io` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `writer_empty_buf`
- **after:** `writer_4kib_buf`
- ops=50000
- Raw: [`zp-unbuffered-io.jsonl`](zp-unbuffered-io.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~7.29 ms |
| Median after | ~0.1487 ms |
| **ratio before/after** | **~49×** |

## Lint mapping

`zperf-lint` `zp-unbuffered-io` / `unbuffered-io`. Default severity in `rules.zig` is **off** (the CLI does not report the rule); see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~49.0× wall; matches guide p19 (~50×).

## Limits

One-shot writes / readVec-writeVec / tests skipped by lint.
