# zp-static-string-map — static-string-map

## Claim

StringHashMap.get vs StaticStringMap.get (literal keys) under Zig **0.17.0** `-Ofast` on this Linux machine shows a clear before/after wall-clock gap.

## How measured

- Harness: `packages/zperf/examples/bench/evidence_fill.zig` (rule `zp-static-string-map` cases)
- Build: `zig build-exe -Ofast` · optimize_mode=`fast`
- Timing: `Io.Clock` awake; warm=2; **median of 9** rounds
- **before:** `string_hashmap_get`
- **after:** `static_string_map_get`
- ops=200000
- Raw: [`zp-static-string-map.jsonl`](zp-static-string-map.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Zig | **0.17.0** · `fast` |
| Median before | ~1.515 ms |
| Median after | ~0.5995 ms |
| **ratio before/after** | **~2.53×** |

## Lint mapping

`zperf-lint` `zp-static-string-map` / `static-string-map`. Default severity in `rules.zig` is **info**; see [evidence-policy](../docs/evidence-policy.md) for keep/escalate. Evidence exists and **agrees** directionally.

## Verdict

Agree ~2.53× lookup; Static also zero runtime alloc/init.

## Limits

Only fires when ≥3 literal puts in one function.
