# oc-nslog-in-loop — fprintf/NSLog-like in loop

**Status:** measured (gnustep proxy)

## Claim

Per-iteration `fprintf(stderr,…)` to `/dev/null` vs once ~**191×** (proxy for NSLog chatter).

## How measured

- Harness: `packages/objcperf/examples/bench/evidence_oc.m`
- N=10000
- Raw lines: [`oc-nslog-in-loop.jsonl`](oc-nslog-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| runtime | **gnustep** |
| Median before (`fprintf_in_loop`) | ~0.6143 ms |
| Median after (`log_once`) | ~0.003217 ms |
| **ratio before/after** | **~191×** |

## Lint mapping

`objcperf-lint` oc-nslog-in-loop: default stays **`off`**.

## Limits

- Not true NSLog; I/O proxy. Default stays **off**.
