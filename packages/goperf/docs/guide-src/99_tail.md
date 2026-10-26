## Lint map

| ID | Smell | Default |
|----|-------|---------|
| gp-make-in-loop | `make`/`new` in loop | off (G3) |
| gp-string-plus-in-loop | string `+=` in loop | off (G3) |
| gp-fmt-in-loop | `fmt.Sprintf`/`Printf` in loop | off (G3) |
| gp-append-nil-slice | empty slice + append in size-hinted loop | hint |
| gp-defer-in-loop | `defer` in loop | hint |
| gp-regexp-compile-in-loop | `regexp.Compile` in loop | hint (measured; not corpus-triaged) |
| gp-json-marshal-in-loop | `json.Marshal` / `Unmarshal` in loop | hint (measured; not corpus-triaged) |
| gp-reflect-in-loop | `FieldByName` / `MethodByName` / `reflect.New` in loop | hint (JSONL; `TypeOf` is not matched) |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
