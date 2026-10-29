## Lint map

| ID | Smell | Default |
|----|-------|---------|
| sp-print-hot | `print(` in loop | off (about 10× a String; stdout discarded) |
| sp-array-no-reserve | empty Array then append without `reserveCapacity` | hint (about 5× small, about 1.6× one large fill) |
| sp-dateformatter-hot | date formatter constructed in a loop | hint (JSONL present; not corpus-triaged) |
| sp-json-decode-hot | JSON decoder or jsonObject in a loop | hint (JSONL present; not corpus-triaged) |
| sp-regex-hot | regular expression constructed in a loop | hint (JSONL present; not corpus-triaged) |

Enable an `off` rule with `--severity <rule>=hint`. The five rules from 2026-10-22 still have no JSONL. The three rows added 2026-10-23 have a JSONL microbench and stay **hint**. They are not part of the 2026-10-22 corpus-ready verdict. See [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
