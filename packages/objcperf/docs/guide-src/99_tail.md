## Lint map

| ID | Smell | Default |
|----|-------|---------|
| oc-nsstring-append-in-loop | stringByAppendingString in loop | off |
| oc-nslog-in-loop | NSLog in loop | off |
| oc-dateformatter-in-loop | date formatter alloc/init or new in a loop | hint (JSONL present; not corpus-triaged) |
| oc-json-in-loop | JSON parse or encode in a loop | hint (JSONL present; not corpus-triaged) |
| oc-regex-in-loop | regular expression compiled in a loop | hint (JSONL present; not corpus-triaged) |

Escalate only with `evidence/oc-*.jsonl` — see [evidence-policy.md](evidence-policy.md). The two array-capacity rules (OC001, OC004) were removed; see [rule-ids.md](rule-ids.md). `oc-dateformatter-in-loop`, `oc-json-in-loop`, and `oc-regex-in-loop` have a JSONL microbench and stay hint. They are not part of the 2026-10-22 corpus-ready verdict.

## References

- [XPerf playbook](../../../docs/playbook.md)
- [swiftperf](../../swiftperf/) (sibling)
