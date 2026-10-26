## Lint map

| ID | Smell | Default |
|----|-------|---------|
| kt-list-add-in-loop | list alloc / add growth in loop | off |
| kt-string-plus-in-loop | string `+=` in loop | off |
| kt-println-in-loop | `println` in loop | off |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md). Measured JVM claims: [jvmperf](../../jvmperf/).

## References

- [XPerf playbook](../../../docs/playbook.md)
- [jvmperf](../../jvmperf/)
