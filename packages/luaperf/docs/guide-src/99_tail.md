## Lint map

| ID | Smell | Default |
|----|-------|---------|
| lu-table-insert-hot | table.insert / grow in loop | off |
| lu-string-concat-hot | string `..` in loop | error |
| lu-print-hot | `print` in loop | hint |

Escalate only with `evidence/lu-*.jsonl` — see [evidence-policy.md](evidence-policy.md). lu-print-hot has measured evidence but stays **hint** (I/O sink–dependent).

## References

- [XPerf playbook](../../../docs/playbook.md)
