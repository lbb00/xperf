# lu-table-insert-in-loop — table.insert vs t[i]=

## Claim

Measured on this machine: primary hot case **`table_insert`** ratio before/after **~4.74×** (faster after). Default severity stays **`off`**. Do **not** escalate to `error` from this fill alone.

## How measured

- Harness: `packages/luaperf/examples/bench/evidence_lu001.lua`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`lu-table-insert-in-loop.jsonl`](lu-table-insert-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **Lua 5.4.7** |
| Median after (`index_assign`) | 2.029000 ms (ops=200000, ratio=1.000000) |
| Median before (`table_insert`) | 9.620000 ms (ops=200000, ratio=4.741252) |
| Median after (`hash_len_append`) | 3.926000 ms (ops=200000, ratio=1.000000) |
| Median before (`table_insert_vs_len`) | 9.620000 ms (ops=200000, ratio=2.450331) |
| Median after (`small_index`) | 3.814000 ms (ops=100, ratio=1.000000) |
| Median before (`small_insert`) | 13.184000 ms (ops=100, ratio=3.456738) |
| **Primary ratio before/after** | **~4.74×** (`table_insert`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`luaperf-lint` **lu-table-insert-in-loop** default stays **`off`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
