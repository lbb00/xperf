## Lint map

| ID | Smell | Default |
|----|-------|---------|
| oc-nsstring-append-hot | stringByAppendingString in loop | off |
| oc-nslog-hot | NSLog in loop | off |
| oc-dateformatter-hot | date formatter alloc/init or new in a loop | hint (JSONL present; not corpus-triaged) |
| oc-json-hot | JSON parse or encode in a loop | hint (JSONL present; not corpus-triaged) |
| oc-regex-hot | regular expression compiled in a loop | hint (JSONL present; not corpus-triaged) |

Escalate only with `evidence/oc-*.jsonl` — see [evidence-policy.md](evidence-policy.md). The two array-capacity rules (OC001, OC004) were removed; see [rule-ids.md](rule-ids.md). `oc-dateformatter-hot`, `oc-json-hot`, and `oc-regex-hot` have a JSONL microbench and stay hint. They are not part of the 2026-10-22 corpus-ready verdict.

## References

- [XPerf playbook](../../../docs/playbook.md)
- [swiftperf](../../swiftperf/) (sibling)
