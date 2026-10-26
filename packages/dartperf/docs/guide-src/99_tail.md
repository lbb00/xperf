## Lint map

| ID | Smell | Default |
|----|-------|---------|
| dt-list-add-empty | List grow / `add` without capacity cue | off |
| dt-string-plus-in-loop | string `+` in loop | off |
| dt-print-in-loop | `print` in loop | off |
| dt-growable-add-empty | empty growable list + `add` in size-hinted loop | hint |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
