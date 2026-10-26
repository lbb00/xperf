## Lint map

| ID | Smell | Default |
|----|-------|---------|
| rs-alloc-in-loop | alloc/clone in loop | off (G3 OK-idiom; G4 measured) |
| rs-println-in-loop | println! / eprintln! in loop | hint |
| rs-format-rebind-in-loop | `format!` rebind accum in loop | **error** (G4: ~99× vs `write!`) |
| rs-collect-vec-in-loop | collect::<Vec> in loop | hint |
| rs-regex-new-in-loop | `Regex::new` in loop | hint (JSONL about 963× on a short haystack) |

See [evidence-policy.md](evidence-policy.md). Demote rs-format-rebind-in-loop with `--severity rs-format-rebind-in-loop=hint` if one-shot wraps dominate. Amortized `+=` and large `Vec::new` plus push were removed.

## References

- [XPerf playbook](../../../docs/playbook.md)
