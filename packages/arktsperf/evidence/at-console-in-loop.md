# at-console-in-loop — console in loop (Node proxy)

**Status:** measured (node-proxy)

## Claim

Per-iteration `console.log` (stdout discarded) is much slower than a quiet loop + one log on Node/V8.

## How measured

- Harness: `examples/bench/evidence_at001_at003.js`
- **runtime: node-proxy**
- N_CONSOLE=20000

- Raw lines: [`at-console-in-loop.jsonl`](at-console-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| runtime | **node-proxy** |
| node | **v20.19.2** |
| v8 | **11.3.244.8-node.38** |
| Median before (`console_in_loop`) | ~24.79 ms |
| Median after (`quiet_then_once`) | ~0.1194 ms |
| **ratio before/after** | **~208×** |

## Lint mapping

`arktsperf-lint` at-console-in-loop: severity stays package default (see evidence-policy). JSONL is **Node proxy**, not device.

## Limits

- I/O / console env dependent.
- Default stays **off**.
