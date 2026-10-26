# pp-list-plus-rebind — xs = xs + [i] vs append

## Claim

Measured on this machine: primary hot case **`list_plus_rebind`** ratio before/after **~1872.93×** (faster after). Default severity stays **`hint`**. Do **not** escalate to `error` from this fill alone — ratio is strong but policy/default and G3 OK-idiom history keep severity unchanged.

## How measured

- Harness: `packages/pyperf/examples/bench/evidence_pp.py`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`pp-list-plus-rebind.jsonl`](pp-list-plus-rebind.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **CPython 3.15.1** |
| Median after (`list_append`) | 0.302584 ms (ops=20000, ratio=1.000000) |
| Median before (`list_plus_rebind`) | 566.717875 ms (ops=20000, ratio=1872.927988) |
| Median after (`small_append`) | 0.006208 ms (ops=100, ratio=1.000000) |
| Median before (`small_list_plus`) | 0.013167 ms (ops=100, ratio=2.120912) |
| **Primary ratio before/after** | **~1872.93×** (`list_plus_rebind`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`pyperf-lint` **pp-list-plus-rebind** default stays **`hint`**. Escalate recommended: **no (strong microbench, keep current default; escalate needs policy candidate + corpus agreement)**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
