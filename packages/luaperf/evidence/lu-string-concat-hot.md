# lu-string-concat-hot — string `..` accumulation in loop

## Claim

Building a string with `s = s .. chunk` inside a numeric/`for` loop is substantially slower than collecting parts then `table.concat` on Lua 5.4, because each `..` copies the growing prefix (classic quadratic cost). Magnitude grows with N and chunk size; tiny N can be ~1×.

## How measured

- Harness: `packages/luaperf/examples/bench/evidence_lu002.lua`
- Timer: Lua `os.clock()` (CPU seconds; single-threaded kernels ≈ wall on this machine)
- Protocol: warm=3; median of 9 rounds; `collectgarbage("collect")` before each timed sample
- Pair A (matches fixtures `bad/lu-string-concat-hot_concat_loop.lua` / `good/lu-string-concat-hot_concat.lua`): N=20000
  - **before:** `s = s .. tostring(i)` in loop
  - **after:** `parts[i] = tostring(i)` then `table.concat(parts)`
- Pair B (fixed 32-byte chunks): N=10000
  - **before:** `s = s .. chunk` in loop
  - **after:** index-fill parts then `table.concat`
- Pair C (small N oneshot-ish): N=100 — expect ~1×
- Raw lines: [`lu-string-concat-hot.jsonl`](lu-string-concat-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL `ts` is UTC) |
| Lua | **Lua 5.4.7** |
| Median before (`digits_concat_loop`) | 54.149 ms |
| Median after (`digits_table_concat`) | 8.248 ms |
| **ratio digits before/after** | **~6.57×** |
| Median before (`chunk32_concat_loop`) | 60.630 ms |
| Median after (`chunk32_table_concat`) | 0.518 ms |
| **ratio chunk32 before/after** | **~117×** |
| Median before (`small_n_concat_loop`) | 0.032 ms |
| Median after (`small_n_table_concat`) | 0.033 ms |
| **ratio small N** | **~0.97×** (~1×) |

Direction stable across pairs; absolute ms and ratio are N/chunk/machine-sensitive (quadratic). Re-run the harness after Lua or machine changes.

## Lint mapping

`luaperf-lint` lu-string-concat-hot flags string accumulation `s = s .. x` inside a loop window (not one-shot key builds like `k .. "=" .. v` — see `good/lu-string-concat-hot_oneshot_key.lua`). Default severity is **`error`** under [evidence-policy](../docs/evidence-policy.md): this JSONL exists, wall/CPU agrees on hot accumulation, and G3 corpus residuals (e.g. APISIX http-dubbo) looked like honest TPs. Small/cold loops may still be fine — override with `--severity lu-string-concat-hot=hint` or `off` when the loop is not hot.

## Limits

- Microbench; not an app profile.
- Timer is `os.clock()` CPU time, not `CLOCK_MONOTONIC`; fine for ST CPU-bound string work, not for I/O-bound paths.
- Pair C shows the smell is situational at tiny N — do not treat every `..` as a crash bug.
- Does not measure `__concat` metamethods or userdata.
- Historical note: lu-table-insert-hot remains `off`; kit later flipped **corpus-ready** post-G4 recheck (see docs/corpus.md).
