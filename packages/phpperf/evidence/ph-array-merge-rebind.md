# ph-array-merge-rebind — `$a = array_merge($a, …)` rebinding in loop

## Claim

Rebinding an accumulator with `$a = array_merge($a, $chunk)` inside a loop is substantially slower than appending with `$a[] = …` (or `array_push`) on PHP 8.4, because each `array_merge` allocates and copies the growing prefix (classic quadratic cost). Magnitude grows with N and chunk size; even N≈100 still shows a clear gap on this machine.

## How measured

- Harness: `packages/phpperf/examples/bench/evidence_ph002.php`
- Timer: PHP `hrtime(true)` wall nanoseconds
- Protocol: warm=3; median of 9 rounds; `gc_collect_cycles()` before each timed sample
- Pair A (matches fixtures `bad/ph-array-merge-rebind_array_merge.php` / `good/ph-array-merge-rebind_push.php`): N=20000
  - **before:** `$a = array_merge($a, [$i])` in loop
  - **after:** `$a[] = $i` in loop
- Pair B (fixed 8-element chunks): N=5000
  - **before:** `$a = array_merge($a, $chunk)` in loop
  - **after:** foreach-push into `$a`
- Pair C (small N): N=100 — still multi-×; absolute ms tiny
- Raw lines: [`ph-array-merge-rebind.jsonl`](ph-array-merge-rebind.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai (machine clock; JSONL `ts` is UTC) |
| PHP | **PHP 8.5.12** |
| Median before (`scalar_array_merge`) | 243.229 ms |
| Median after (`scalar_push`) | 0.234 ms |
| **ratio scalar before/after** | **~1038×** |
| Median before (`chunk8_array_merge`) | 153.429 ms |
| Median after (`chunk8_push`) | 0.267 ms |
| **ratio chunk8 before/after** | **~574×** |
| Median before (`small_n_array_merge`) | 0.019 ms |
| Median after (`small_n_push`) | 0.001 ms |
| **ratio small N** | **~12.8×** |

Direction stable across pairs; absolute ms and ratio are N/chunk/machine-sensitive (quadratic). Re-run the harness after PHP or machine changes.

## Lint mapping

`phpperf-lint` ph-array-merge-rebind flags same-var growing rebind `$a = array_merge($a, …)` inside a loop window (not one-shot merges outside loops — see `good/ph-array-merge-rebind_oneshot_merge.php`). Default severity is **`error`** under [evidence-policy](../docs/evidence-policy.md): this JSONL exists, wall agrees on hot accumulation, and G3 corpus residuals (Composer/Laravel) looked like honest TPs. Cold/tiny builders may still be fine — override with `--severity ph-array-merge-rebind=hint` or `off` when the loop is not hot.

## Limits

- Microbench; not an app profile.
- Does not measure `array_merge` for *key* overlays / associative remap (rule targets growing list rebind).
- Pair C absolute times are near timer noise; ratio still favors push.
- Historical note: ph-string-dot-in-loop later demoted `off`; kit flipped **corpus-ready** post-G4 recheck (see docs/corpus.md).
