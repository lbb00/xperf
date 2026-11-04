## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| cs-list-add-no-capacity | 循环内无 Capacity 的 `List.Add` | off |
| cs-string-plus-hot | 循环内字符串 `+=` | off |
| cs-console-hot | 循环内 `Console.Write*` | off |
| cs-regex-hot | 循环内静态 `Regex.IsMatch/Match` | hint |
| cs-linq-materialize-hot | 循环内 `ToList` / `ToArray` / `ToDictionary` | hint（待测） |
| cs-format-hot | 循环内 `string.Format` | hint（待测） |
| cs-json-hot | 循环内 JSON 编解码 | hint（有 JSONL，仅固定 payload） |

仅在有 `evidence/<rule>.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
