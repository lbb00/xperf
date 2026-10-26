# at-object-delete — object delete (Node proxy)

**Status:** measured-inconclusive (node-proxy)

## Claim

On this Node/V8 microbench, `delete` on a null-prototype object vs `Map.delete` was **~1×** — **inconclusive** as a speed gate.

## How measured

- Harness: `examples/bench/evidence_at001_at003.js`
- **runtime: node-proxy**

- Raw lines: [`at-object-delete.jsonl`](at-object-delete.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| runtime | **node-proxy** |
| node | **v20.19.2** |
| v8 | **11.3.244.8-node.38** |
| Median before (`object_delete`) | ~1.341 ms |
| Median after (`map_delete_free`) | ~1.323 ms |
| **ratio before/after** | **~1.01×** |

## Lint mapping

`arktsperf-lint` at-object-delete: severity stays package default (see evidence-policy). JSONL is **Node proxy**, not device.

## Limits

- Do not treat as proof of speedup. Shape/IC effects need a different harness.
- Default stays **off**.

## Landed 2026-10-22

Deep-dive: original harness timed **fill + delete** together (fill dominates → ~1×). Isolated delete-only on Node is modest (~1.7× obj vs Map). Still **node-proxy**; keep **off**. No speed escalate.
