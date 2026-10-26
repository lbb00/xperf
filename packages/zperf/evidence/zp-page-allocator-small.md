# zp-page-allocator-small — page-allocator-small

## Claim

page_allocator 64B alloc+free vs process GPA (smp/c in ReleaseFast) under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-page-allocator-small` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `page_allocator_64B`
- **after:** `process_gpa_64B`
- ops=20000
- Raw: [`zp-page-allocator-small.jsonl`](zp-page-allocator-small.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~137.1 ms |
| Median after | ~0.4018 ms |
| **ratio before/after** | **~341×** |

## Lint mapping

`zperf-lint` `zp-page-allocator-small` / `page-allocator-small`. Default severity in `rules.zig` is **warning**; see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~341× — page allocator pays syscall/page per small block.

## Limits

Large mmap-sized buffers can still use page_allocator intentionally.
