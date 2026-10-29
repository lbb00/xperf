# gp-fmt-hot — fmt.Sprintf in loop vs strconv/Builder

## Claim

Measured on this machine: primary hot case **`fmt_sprintf_vs_itoa`** ratio before/after **~2.81×** (faster after). Default severity stays **`off`**. Do **not** escalate to `error` from this fill alone.

## How measured

- Harness: `packages/goperf/examples/bench/evidence_gp.go`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`gp-fmt-hot.jsonl`](gp-fmt-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **go1.27.3** |
| Median after (`strconv_builder`) | 5.100292 ms (ops=100000, ratio=1.000000) |
| Median before (`fmt_sprintf_loop`) | 6.008417 ms (ops=100000, ratio=1.178054) |
| Median after (`strconv_itoa_only`) | 2.137083 ms (ops=100000, ratio=1.000000) |
| Median before (`fmt_sprintf_vs_itoa`) | 6.008417 ms (ops=100000, ratio=2.811504) |
| **Primary ratio before/after** | **~2.81×** (`fmt_sprintf_vs_itoa`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`goperf-lint` **gp-fmt-hot** default stays **`off`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
