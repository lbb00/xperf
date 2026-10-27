## Lint map

| ID | Smell | Default |
|----|-------|---------|
| kt-list-add-hot | list alloc / add growth in loop | off |
| kt-string-plus-hot | string `+=` in loop | off |
| kt-println-hot | `println` in loop | off |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md). Measured JVM claims: [jvmperf](../../jvmperf/).

## References

- [XPerf playbook](../../../docs/playbook.md)
- [jvmperf](../../jvmperf/)
