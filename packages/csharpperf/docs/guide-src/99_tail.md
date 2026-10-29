## Lint map

| ID | Smell | Default |
|----|-------|---------|
| cs-list-add-no-capacity | `List.Add` in loop without Capacity | off |
| cs-string-plus-hot | string `+=` in loop | off |
| cs-console-hot | `Console.Write*` in loop | off |
| cs-regex-hot | static `Regex.IsMatch/Match` in loop | hint |
| cs-linq-materialize-hot | `ToList` / `ToArray` / `ToDictionary` in loop | hint (pending measure) |
| cs-format-hot | `string.Format` in loop | hint (pending measure) |
| cs-json-hot | JSON encode/decode in loop | hint (JSONL, fixed payload only) |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
