## Lint map

| ID | Smell | Default |
|----|-------|---------|
| cs-list-add-no-capacity | `List.Add` in loop without Capacity | off |
| cs-string-plus-in-loop | string `+=` in loop | off |
| cs-console-in-loop | `Console.Write*` in loop | off |
| cs-regex-in-loop | static `Regex.IsMatch/Match` in loop | hint |
| cs-linq-materialize-in-loop | `ToList` / `ToArray` / `ToDictionary` in loop | hint (pending measure) |
| cs-format-in-loop | `string.Format` in loop | hint (pending measure) |
| cs-json-in-loop | JSON encode/decode in loop | hint (JSONL, fixed payload only) |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
