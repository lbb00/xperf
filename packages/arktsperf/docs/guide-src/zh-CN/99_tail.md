## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| at-alloc-hot | 循环内分配类写法 | off |
| at-console-hot | 循环内 console / bridge 噪声 | off |
| at-includes-hot | 循环内 `includes` / `indexOf` | hint |
| at-json-hot | 循环内 `JSON.parse` / `stringify` | hint |

仅在 `evidence/at-*.jsonl` 之上再叠加真机或 ArkTS-VM bench 时才升级（见 [evidence-policy.md](evidence-policy.md)）。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
- [jsperf 指南](../../../jsperf/docs/zh-CN/js-performance-guide.md)（相关，但不相同）
