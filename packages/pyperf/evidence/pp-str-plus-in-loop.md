# pp-str-plus-in-loop — str += vs str.join

## Claim

Measured on this machine: primary hot case **`str_plus`** ratio before/after **~11.60×** (faster after). Default severity stays **`off`**. Do **not** escalate to `error` from this fill alone.

## How measured

- Harness: `packages/pyperf/examples/bench/evidence_pp.py`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`pp-str-plus-in-loop.jsonl`](pp-str-plus-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **CPython 3.15.1** |
| Median after (`str_join`) | 0.243541 ms (ops=50000, ratio=1.000000) |
| Median before (`str_plus`) | 2.824209 ms (ops=50000, ratio=11.596449) |
| Median after (`small_join`) | 0.003750 ms (ops=100, ratio=1.000000) |
| Median before (`small_str_plus`) | 0.007625 ms (ops=100, ratio=2.033404) |
| **Primary ratio before/after** | **~11.60×** (`str_plus`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`pyperf-lint` **pp-str-plus-in-loop** default stays **`off`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
