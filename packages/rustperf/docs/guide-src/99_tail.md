## Lint map

| ID | Smell | Default |
|----|-------|---------|
| rs-alloc-hot | alloc/clone in loop | off (G3 OK-idiom; G4 measured) |
| rs-println-hot | println! / eprintln! in loop | hint |
| rs-format-rebind-hot | `format!` rebind accum in loop | **error** (G4: ~99× vs `write!`) |
| rs-collect-vec-hot | collect::<Vec> in loop | hint |
| rs-regex-new-hot | `Regex::new` in loop | hint (JSONL about 963× on a short haystack) |

See [evidence-policy.md](evidence-policy.md). Demote rs-format-rebind-hot with `--severity rs-format-rebind-hot=hint` if one-shot wraps dominate. Amortized `+=` and large `Vec::new` plus push were removed.

## References

- [XPerf playbook](../../../docs/playbook.md)
