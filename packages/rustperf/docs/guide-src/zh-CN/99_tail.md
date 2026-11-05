## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| rs-alloc-hot | 循环内 alloc/clone | off（G3 OK-idiom；G4 有测量） |
| rs-println-hot | 循环内 println! / eprintln! | hint |
| rs-format-rebind-hot | 循环内 `format!` 重绑定累加 | error（G4：相对 `write!` 约 99×） |
| rs-collect-vec-hot | 循环内 collect::<Vec> | hint |
| rs-regex-new-hot | 循环内 `Regex::new` | hint（短 haystack 上 JSONL 约 963×） |

见 [evidence-policy.md](evidence-policy.md)。若一次性包装占主导，可用 `--severity rs-format-rebind-hot=hint` 降级。摊销的 `+=` 与大 `Vec::new` + push 已移除。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
