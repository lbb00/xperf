## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| ph-string-dot-hot | 循环内字符串 `.=` | off |
| ph-array-merge-rebind | 循环内 `array_merge` 重绑定 | error |
| ph-echo-hot | 循环内 `echo` / `print` | hint |

仅在有 `evidence/ph-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
