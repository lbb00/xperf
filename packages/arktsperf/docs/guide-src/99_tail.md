## Lint map

| ID | Smell | Default |
|----|-------|---------|
| at-alloc-in-loop | alloc-like in loop | off |
| at-console-in-loop | console / bridge chatter in loop | off |
| at-includes-in-loop | `includes` / `indexOf` in loop | hint |
| at-json-in-loop | `JSON.parse` / `stringify` in loop | hint |

Escalate only with a device or ArkTS-VM bench on top of `evidence/at-*.jsonl` (see [evidence-policy.md](evidence-policy.md)).

## References

- [XPerf playbook](../../../docs/playbook.md)
- [jsperf guide](../../jsperf/docs/js-performance-guide.md) (related, not identical)
