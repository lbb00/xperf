## Lint map

| ID | Smell | Default |
|----|-------|---------|
| pp-str-plus-in-loop | string `+=` in loop | off (G3) |
| pp-list-plus-rebind | list `+` rebinding in loop | hint |
| pp-print-in-loop | `print(` in loop | off (G3) |
| pp-json-in-loop | `json.loads` / `dumps` in loop | hint (measured; not corpus-triaged) |
| pp-deepcopy-in-loop | `deepcopy` in loop | hint (measured; not corpus-triaged) |

Escalate only with `evidence/pp-*.jsonl` — see [evidence-policy.md](evidence-policy.md). The ad-hoc `re.METHOD(literal)` rule (PP004) was removed; see [rule-ids.md](rule-ids.md). `pp-regex-compile-in-loop` and `pp-datetime-format-in-loop` were removed.

## References

- [XPerf playbook](../../../docs/playbook.md)
