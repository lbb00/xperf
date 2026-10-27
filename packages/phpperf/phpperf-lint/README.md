# phpperf-lint

Pure-PHP CLI heuristic checker for **ph-string-dot-hot–ph-echo-hot**.

| Rule | Message |
|------|---------|
| ph-string-dot-hot | string `.=` in loop; prefer `implode` / collector |
| ph-array-merge-rebind | `array_merge` rebinding in loop; prefer `$a[] = …` |
| ph-echo-hot | `echo` / `print` in loop; gate or buffer |

Default severity: **ph-string-dot-hot=off**, **ph-array-merge-rebind=error** (G4 evidence), **ph-echo-hot=hint**. Re-enable ph-string-dot-hot with `--severity ph-string-dot-hot=hint`; demote ph-array-merge-rebind with `--severity ph-array-merge-rebind=hint`. Self-dogfood: `bash ../scripts/self-lint.sh`.
