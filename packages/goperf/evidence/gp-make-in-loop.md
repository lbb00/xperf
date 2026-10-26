# gp-make-in-loop — make([]byte) each iter vs reuse / single slice

## Claim

Measured on this machine: primary hot case **`make_each_iter`** ratio before/after **~160.26×** (faster after). Default severity stays **`off`**. Do **not** escalate to `error` from this fill alone — ratio is strong but policy/default and G3 OK-idiom history keep severity unchanged.

## How measured

- Harness: `packages/goperf/examples/bench/evidence_gp.go`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`gp-make-in-loop.jsonl`](gp-make-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **go1.27.3** |
| Median after (`reuse_buf`) | 0.057417 ms (ops=200000, ratio=1.000000) |
| Median before (`make_each_iter`) | 9.201458 ms (ops=200000, ratio=160.256684) |
| Median after (`single_slice_fill`) | 0.362708 ms (ops=50000, ratio=1.000000) |
| Median before (`make_append_slices`) | 2.214292 ms (ops=50000, ratio=6.104889) |
| **Primary ratio before/after** | **~160.26×** (`make_each_iter`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`goperf-lint` **gp-make-in-loop** default stays **`off`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
