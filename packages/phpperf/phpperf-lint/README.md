# phpperf-lint

Pure-PHP CLI heuristic checker for **ph-string-dot-in-loop–ph-echo-in-loop**.

| Rule | Message |
|------|---------|
| ph-string-dot-in-loop | string `.=` in loop; prefer `implode` / collector |
| ph-array-merge-rebind | `array_merge` rebinding in loop; prefer `$a[] = …` |
| ph-echo-in-loop | `echo` / `print` in loop; gate or buffer |

Default severity: **ph-string-dot-in-loop=off**, **ph-array-merge-rebind=error** (G4 evidence), **ph-echo-in-loop=hint**. Re-enable ph-string-dot-in-loop with `--severity ph-string-dot-in-loop=hint`; demote ph-array-merge-rebind with `--severity ph-array-merge-rebind=hint`. Self-dogfood: `bash ../scripts/self-lint.sh`.
