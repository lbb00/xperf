## Lint map

| ID | Smell | Default |
|----|-------|---------|
| rb-string-plus-hot | string `+=` in loop | off |
| rb-array-plus-rebind | Array `+` / concat rebinding in loop | off |
| rb-puts-hot | `puts` / `print` in loop | off |
| rb-regexp-new-hot | `Regexp.new` in loop | hint (measured; not corpus-triaged) |
| rb-json-hot | `JSON.parse` / `generate` in loop | hint (measured; not corpus-triaged) |

Enable an `off` rule with `--severity <rule>=hint`. Escalate to `error` only with measured `evidence/rb-*.jsonl` — see [evidence-policy.md](evidence-policy.md). `rb-date-parse-in-loop` and `rb-hash-merge-in-loop` were removed.

## References

- [XPerf playbook](../../../docs/playbook.md)
