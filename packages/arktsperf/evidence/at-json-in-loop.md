# at-json-in-loop — JSON.parse/stringify in loop (Node proxy)

**Status:** measured (node-proxy)

## Claim

Parsing many small JSON strings in a loop is slower than one `JSON.parse` of an array blob; per-item `stringify` is modestly slower than one array stringify on Node/V8.

## How measured

- Harness: `examples/bench/evidence_at004_at005.js`
- **runtime: node-proxy**
- N=20000

- Raw lines: [`at-json-in-loop.jsonl`](at-json-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| runtime | **node-proxy** |
| node | **v20.19.2** |
| v8 | **11.3.244.8-node.38** |
| Median before (`parse_in_loop`) | ~8.702 ms |
| Median after (`parse_once_array`) | ~3.895 ms |
| **ratio before/after** | **~2.23×** |
| Median before (`stringify_in_loop`) | ~2.985 ms |
| Median after (`stringify_once`) | ~1.781 ms |
| **ratio before/after** | **~1.68×** |

## Lint mapping

`arktsperf-lint` at-json-in-loop: severity stays package default (see evidence-policy). JSONL is **Node proxy**, not device.

## Limits

- Modest ratios (~2× parse, ~1.7× stringify).
- Default stays **hint**.
