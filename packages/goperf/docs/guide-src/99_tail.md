## Lint map

| ID | Smell | Default |
|----|-------|---------|
| gp-make-hot | `make`/`new` in loop | off (G3) |
| gp-string-plus-hot | string `+=` in loop | off (G3) |
| gp-fmt-hot | `fmt.Sprintf`/`Printf` in loop | off (G3) |
| gp-append-nil-slice | empty slice + append in size-hinted loop | hint |
| gp-defer-hot | `defer` in loop | hint |
| gp-regexp-compile-hot | `regexp.Compile` in loop | hint (measured; not corpus-triaged) |
| gp-json-marshal-hot | `json.Marshal` / `Unmarshal` in loop | hint (measured; not corpus-triaged) |
| gp-reflect-hot | `FieldByName` / `MethodByName` / `reflect.New` in loop | hint (JSONL; `TypeOf` is not matched) |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
