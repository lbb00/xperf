# zp-queue-ordered-remove — queue-ordered-remove

## Claim

ArrayList.orderedRemove(0) drain vs ring head advance under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-queue-ordered-remove` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `ordered_remove_0`
- **after:** `ring_head_advance`
- ops=4000
- Raw: [`zp-queue-ordered-remove.jsonl`](zp-queue-ordered-remove.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~0.5391 ms |
| Median after | ~0.001157 ms |
| **ratio before/after** | **~466×** |

## Lint mapping

`zperf-lint` `zp-queue-ordered-remove` / `queue-ordered-remove`. Default severity in `rules.zig` is **warning**; see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~466× for FIFO drain of N=4000 (O(N²) shifts).

## Limits

Tiny bounded queues may still use orderedRemove; swapRemove if order free.
