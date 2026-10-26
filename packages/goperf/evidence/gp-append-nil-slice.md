# gp-append-nil-slice — append on nil slice vs make(...,0,len)

## Claim

Measured on this machine: primary hot case **`append_grow`** ratio before/after **~7.28×** (faster after). Default severity stays **`hint`**. Do **not** escalate to `error` from this fill alone — ratio is strong but policy/default and G3 OK-idiom history keep severity unchanged.

## How measured

- Harness: `packages/goperf/examples/bench/evidence_gp.go`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`gp-append-nil-slice.jsonl`](gp-append-nil-slice.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **go1.27.3** |
| Median after (`presize_make`) | 0.336292 ms (ops=500000, ratio=1.000000) |
| Median before (`append_grow`) | 2.448459 ms (ops=500000, ratio=7.280753) |
| Median after (`small_presize`) | 0.000167 ms (ops=100, ratio=1.000000) |
| Median before (`small_append_grow`) | 0.000166 ms (ops=100, ratio=0.994012) |
| **Primary ratio before/after** | **~7.28×** (`append_grow`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`goperf-lint` **gp-append-nil-slice** default stays **`hint`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
