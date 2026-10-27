## Lint map

| ID | Smell | Default |
|----|-------|---------|
| at-alloc-hot | alloc-like in loop | off |
| at-console-hot | console / bridge chatter in loop | off |
| at-includes-hot | `includes` / `indexOf` in loop | hint |
| at-json-hot | `JSON.parse` / `stringify` in loop | hint |

Escalate only with a device or ArkTS-VM bench on top of `evidence/at-*.jsonl` (see [evidence-policy.md](evidence-policy.md)).

## References

- [XPerf playbook](../../../docs/playbook.md)
- [jsperf guide](../../jsperf/docs/js-performance-guide.md) (related, not identical)
