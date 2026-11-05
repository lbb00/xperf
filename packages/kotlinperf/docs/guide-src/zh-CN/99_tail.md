## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| kt-list-add-hot | 循环内 list 分配 / add 增长 | off |
| kt-string-plus-hot | 循环内字符串 `+=` | off |
| kt-println-hot | 循环内 `println` | off |

仅在有 `evidence/<rule>.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。有测量的 JVM 主张见：[jvmperf](../../../jvmperf/)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
- [jvmperf](../../../jvmperf/)
