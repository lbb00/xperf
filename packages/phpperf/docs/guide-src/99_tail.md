## Lint map

| ID | Smell | Default |
|----|-------|---------|
| ph-string-dot-in-loop | string `.=` in loop | off |
| ph-array-merge-rebind | `array_merge` rebinding in loop | **error** |
| ph-echo-in-loop | `echo` / `print` in loop | hint |

Escalate only with `evidence/ph-*.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
