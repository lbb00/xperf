## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| rb-string-plus-hot | 循环内字符串 `+=` | off |
| rb-array-plus-rebind | 循环内 Array `+` / concat 重绑定 | off |
| rb-puts-hot | 循环内 `puts` / `print` | off |
| rb-regexp-new-hot | 循环内 `Regexp.new` | hint（有测量；未 corpus 分级） |
| rb-json-hot | 循环内 `JSON.parse` / `generate` | hint（有测量；未 corpus 分级） |

用 `--severity <rule>=hint` 启用 `off` 规则。升为 `error` 仅在有测量的 `evidence/rb-*.jsonl`——见 [evidence-policy.md](evidence-policy.md)。`rb-date-parse-in-loop` 与 `rb-hash-merge-in-loop` 已移除。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
