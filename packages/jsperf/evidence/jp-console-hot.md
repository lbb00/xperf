# jp-console-hot — `console.*`

## Claim

Calling `console.log` (and siblings) inside a hot loop is far slower than a quiet loop on V8/Node, even when stdout is discarded — formatting and console plumbing dominate. Real TTYs / pipes are usually worse and **environment-dependent**.

## How measured

- Harness: `packages/jsperf/examples/bench/evidence_jp001_jp002.js`
- N_CONSOLE=20000; warm=3; median of 9
- **before:** `console.log(i)` each iteration (stdout `write` redirected to a discard `Writable`)
- **after (quiet):** same arithmetic, no console
- **after (once):** quiet loop + one `console.log("done", s)` after
- Raw lines: [`jp-console-hot.jsonl`](jp-console-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai |
| Node | **v20.19.2** |
| V8 | **11.3.244.8-node.38** |
| Median before (`console_log_in_loop`) | ~27.2 ms |
| Median after (`quiet_loop`) | ~0.021 ms |
| **ratio console/quiet** | **~1328×** |
| Median `console_once_after` | ~0.11 ms (~5× quiet; still tiny vs in-loop) |

## Lint mapping

jp-console-hot flags `console.*` (default `--scope all` includes sites outside loops; `--scope loop` keeps the former in-loop-only match). Severity stays **`hint`** (`engine`) / **`off`** (`app`) under [evidence-policy](../docs/evidence-policy.md):

- Cost is **real** on this machine even without a TTY.
- Still not an `error` gate: intentional debug loops, test helpers, and CLI progress printers are common; ratio swings with sink (discard vs pipe vs TTY) and logger libraries.
- Treat as a review prompt for extreme stacks (cost adds up even off a hot path), not a “must fix for speed” CI fail under the app preset.

## Limits

- Discard sink understates TTY cost; overstates nothing about “is logging free?” — it is not.
- Does not measure `pino` / structured loggers (often cheaper, still not free in a tight loop).
- Not a shape/JIT smell; orthogonal to jp-alloc-hot/jp-delete-shape/jp-delete-array-hole.
