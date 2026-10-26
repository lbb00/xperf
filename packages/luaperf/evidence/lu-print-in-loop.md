# lu-print-in-loop — `print` in a loop

## Claim

Calling `print(...)` inside a hot numeric/`for` loop is substantially slower than a quiet accumulate (or print once after) on Lua 5.4, even when every `print` is sunk to `/dev/null`. Formatting + write plumbing dominate; a real TTY/pipe is usually worse and **environment-dependent**.

## How measured

- Harness: `packages/luaperf/examples/bench/evidence_lu003.lua`
- Timer: Lua `os.clock()` (CPU seconds)
- Protocol: warm=3; median of 9 rounds; `collectgarbage("collect")` before each timed sample
- **Stdout sink:** `/dev/null` via `_G.print` override (Lua 5.4 `print` writes the C `stdout` FILE*, so `io.stdout = …` alone does **not** redirect; the harness replaces `print`)
- Pair A (matches fixtures `bad/lu-print-in-loop_print_loop.lua` / `good/lu-print-in-loop_print_outside.lua`): N=20000
  - **before:** `print(i)` each iteration
  - **after:** quiet `s = s + i` then `print(s)` once
- Pair B (buffer then one write): N=20000
  - **before:** `print(i)` each iteration
  - **after:** `parts[i] = tostring(i)` then `print(table.concat(parts, "\n"))` once
- Pair C (small N): N=100
- Raw lines: [`lu-print-in-loop.jsonl`](lu-print-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL `ts` is UTC) |
| Lua | **Lua 5.4.7** |
| Stdout | **`/dev/null`** (`_G.print` → `io.open("/dev/null","w")`) |
| Median before (`print_in_loop`) | 7.507 ms |
| Median after (`quiet_then_print_once`) | 0.088 ms |
| **ratio print/quiet** | **~85.3×** |
| Median before (`print_in_loop_vs_buffer`) | 7.551 ms |
| Median after (`buffer_then_one_print`) | 3.783 ms |
| **ratio print/buffer** | **~2.0×** |
| Median before (`small_print_in_loop`) | 0.037 ms |
| Median after (`small_quiet_once`) | 0.001 ms |
| **ratio small N** | **~37×** (after is near timer floor — directional only) |

Direction stable: in-loop `print` costs; quiet/once is cheap. Absolute ms and ratio swing with sink (null vs pipe vs TTY), Lua build, and N. Re-run the harness after Lua or machine changes.

## Lint mapping

`luaperf-lint` lu-print-in-loop flags `print(` inside a loop window (not names like `to_print` — see `good/lu-print-in-loop_to_print_name.lua`). Default severity stays **`hint`** under [evidence-policy](../docs/evidence-policy.md):

- Cost is **real** on this machine even with `/dev/null`.
- Still not an `error` gate (same rationale as jsperf **JP002** / cperf **CP003**): intentional debug loops, test helpers, and CLI progress printers are common; ratio swings hard with the sink; buffering alone is only ~2× here.
- Treat as a review prompt for hot paths; escalate per-tree with `--severity lu-print-in-loop=error` only when the path is known hot and prints are unintentional.

## Limits

- Microbench; not an app profile.
- Timer is `os.clock()` CPU time under a Lua-level `print` override — understates a blocking TTY, may differ from C `stdout` fwrite costs.
- Does not measure `io.write`, custom loggers, or ngx.log.
- Historical note: lu-table-insert-in-loop remains `off`; kit later flipped **corpus-ready** post-G4 recheck (see docs/corpus.md).
