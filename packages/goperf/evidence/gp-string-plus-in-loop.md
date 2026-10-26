# gp-string-plus-in-loop — string += vs strings.Builder

## Claim

Measured on this machine: primary hot case **`string_plus`** ratio before/after **~1481.22×** (faster after). Default severity stays **`off`**. Do **not** escalate to `error` from this fill alone — ratio is strong but policy/default and G3 OK-idiom history keep severity unchanged.

## How measured

- Harness: `packages/goperf/examples/bench/evidence_gp.go`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`gp-string-plus-in-loop.jsonl`](gp-string-plus-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **go1.27.3** |
| Median after (`strings_builder`) | 0.217000 ms (ops=50000, ratio=1.000000) |
| Median before (`string_plus`) | 321.424750 ms (ops=50000, ratio=1481.220046) |
| Median after (`small_builder`) | 0.000334 ms (ops=100, ratio=1.000000) |
| Median before (`small_string_plus`) | 0.001667 ms (ops=100, ratio=4.991018) |
| **Primary ratio before/after** | **~1481.22×** (`string_plus`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`goperf-lint` **gp-string-plus-in-loop** default stays **`off`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
