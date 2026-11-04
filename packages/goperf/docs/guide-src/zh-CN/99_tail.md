## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| gp-make-hot | 循环内 `make`/`new` | off（G3） |
| gp-string-plus-hot | 循环内字符串 `+=` | off（G3） |
| gp-fmt-hot | 循环内 `fmt.Sprintf`/`Printf` | off（G3） |
| gp-append-nil-slice | 空 slice + 有大小提示循环里的 append | hint |
| gp-defer-hot | 循环内 `defer` | hint |
| gp-regexp-compile-hot | 循环内 `regexp.Compile` | hint（有测量；未 corpus 分级） |
| gp-json-marshal-hot | 循环内 `json.Marshal` / `Unmarshal` | hint（有测量；未 corpus 分级） |
| gp-reflect-hot | 循环内 `FieldByName` / `MethodByName` / `reflect.New` | hint（有 JSONL；不匹配 `TypeOf`） |

仅在有 `evidence/<rule>.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
