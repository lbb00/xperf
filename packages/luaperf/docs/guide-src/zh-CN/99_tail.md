## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| lu-table-insert-hot | 循环内 table.insert / 扩容 | off |
| lu-string-concat-hot | 循环内字符串 `..` | error |
| lu-print-hot | 循环内 `print` | hint |

仅在有 `evidence/lu-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。lu-print-hot 有测量证据但仍保持 hint（依赖 I/O sink）。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
