# at-alloc-in-loop — new / alloc in loop (Node proxy)

**Status:** measured (node-proxy)

## Claim

Hot per-iteration `new Uint8Array` is slower than reusing one buffer on **Node/V8** (proxy for ArkTS alloc-in-loop smell).

## How measured

- Harness: `examples/bench/evidence_at001_at003.js`
- **runtime: node-proxy** — not ArkTS VM / device SoftAP
- warm=3; median of 9; N=200000

- Raw lines: [`at-alloc-in-loop.jsonl`](at-alloc-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| runtime | **node-proxy** |
| node | **v20.19.2** |
| v8 | **11.3.244.8-node.38** |
| Median before (`new_in_loop`) | ~4.768 ms |
| Median after (`reuse_buffer`) | ~0.1461 ms |
| **ratio before/after** | **~32.6×** |

## Lint mapping

`arktsperf-lint` at-alloc-in-loop: severity stays package default (see evidence-policy). JSONL is **Node proxy**, not device.

## Limits

- Proxy only; ArkTS/ArkRuntime may differ.
- Default stays **off** (G3 OK-idiom); no escalate.
