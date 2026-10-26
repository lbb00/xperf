# zp-print-in-loop — print-in-loop

## Claim

std.debug.print in loop vs quiet counter (same ops) under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-print-in-loop` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `debug_print_in_loop`
- **after:** `quiet_counter`
- ops=2000
- Raw: [`zp-print-in-loop.jsonl`](zp-print-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~2.86 ms |
| Median after | ~4.5e-05 ms |
| **ratio before/after** | **~6.36e+04×** |

## Lint mapping

`zperf-lint` `zp-print-in-loop` / `print-in-loop`. Default severity in `rules.zig` is **off** (the CLI does not report the rule); see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~63566× — stderr lock + format; env-dependent, like jsperf's jp-console-in-loop.

## Limits

Intentional diagnostics remain; --strict-log-in-loop for std.log. Prefer buffered Io.Writer.
