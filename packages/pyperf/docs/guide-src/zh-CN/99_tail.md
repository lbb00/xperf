## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| pp-str-plus-hot | 循环内字符串 `+=` | off（G3） |
| pp-list-plus-rebind | 循环内 list `+` 重绑定 | hint |
| pp-print-hot | 循环内 `print(` | off（G3） |
| pp-json-hot | 循环内 `json.loads` / `dumps` | hint（有测量；未 corpus 分级） |
| pp-deepcopy-hot | 循环内 `deepcopy` | hint（有测量；未 corpus 分级） |

仅在有 `evidence/pp-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。临时的 `re.METHOD(literal)` 规则（PP004）已移除；见 [rule-ids.md](rule-ids.md)。`pp-regex-compile-in-loop` 与 `pp-datetime-format-in-loop` 已移除。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
