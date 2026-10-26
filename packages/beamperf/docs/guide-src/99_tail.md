## Lint map

| ID | Smell | Default |
|----|-------|---------|
| be-list-concat-reduce | list `++` in loop | hint |
| be-map-merge-in-loop | `Map`/`Keyword.merge` in loop | hint |
| be-enum-map-filter-chain | chained `Enum.map`/`filter` | hint |
| be-io-puts-in-loop | `IO.puts` / `io:format` in loop | off |

Escalate only with `evidence/be-*.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
