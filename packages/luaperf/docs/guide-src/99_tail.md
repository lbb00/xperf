## Lint map

| ID | Smell | Default |
|----|-------|---------|
| lu-table-insert-in-loop | table.insert / grow in loop | off |
| lu-string-concat-in-loop | string `..` in loop | error |
| lu-print-in-loop | `print` in loop | hint |

Escalate only with `evidence/lu-*.jsonl` — see [evidence-policy.md](evidence-policy.md). lu-print-in-loop has measured evidence but stays **hint** (I/O sink–dependent).

## References

- [XPerf playbook](../../../docs/playbook.md)
