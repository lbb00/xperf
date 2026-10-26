# at-includes-in-loop — includes/indexOf in loop (Node proxy)

**Status:** measured (node-proxy)

## Claim

`Array.includes` over a 256-entry list inside a hot loop is much slower than `Set.has` on Node/V8 (**~29×**). Short-alphabet `String.indexOf` vs `Map.get` was **~0.95×** (Map often loses); a dense **LUT** wins (~3× on L=64). Lint message (2026-10-22): Array→Set; String.indexOf→LUT — do **not** push Map for short haystacks.

## How measured

- Harness: `examples/bench/evidence_at004_at005.js`
- Deep-dive (LUT arm): separate script, not shipped in this repo
- **runtime: node-proxy** — not ArkTS VM
- Pairs: includes→Set (N=5e4); indexOf→Map (N=2e5, alphabet len 64); LUT arm in deep-dive

- Raw lines: [`at-includes-in-loop.jsonl`](at-includes-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| runtime | **node-proxy** |
| node | **v20.19.2** |
| v8 | **11.3.244.8-node.38** |
| Median before (`includes_loop`) | ~13.37 ms |
| Median after (`set_has`) | ~0.4637 ms |
| **ratio before/after** | **~28.8×** |
| Median before (`indexOf_loop`) | ~1.954 ms |
| Median after (`map_lookup`) | ~2.056 ms |
| **ratio before/after** | **~0.951×** |

## Lint mapping

`arktsperf-lint` at-includes-in-loop: severity stays **hint**. JSONL is **Node proxy**, not device — non-escalatable alone. Fixture `arktsperf-lint/fixtures/good/at-includes-in-loop_string_lut.ts` documents the String path.

## Limits

- Primary claim is includes→Set. indexOf→Map is not a win on short alphabets; prefer LUT.
- Default stays **hint**; Node proxy alone does not escalate to error.

## Landed 2026-10-22

Matcher message narrowed; LUT good fixture added. Severity unchanged.

## Memory (2026-10-22, node-proxy)

`heapUsed` delta for out array ~1.25–1.43 MiB; Set(256) alone ~**184 KiB**. Smell is CPU (includes→Set), not RAM reduction. [`at-includes-in-loop.mem.jsonl`](at-includes-in-loop.mem.jsonl).
