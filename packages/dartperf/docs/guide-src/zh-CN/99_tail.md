## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| dt-list-add-empty | List 增长 / 无容量线索的 `add` | off |
| dt-string-plus-hot | 循环内字符串 `+` | off |
| dt-print-hot | 循环内 `print` | off |
| dt-growable-add-empty | 空可增长 list + 有大小提示循环里的 `add` | hint |

仅在有 `evidence/<rule>.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
