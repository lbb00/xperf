## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| be-list-concat-reduce | 循环内 list `++` | hint |
| be-map-merge-hot | 循环内 `Map`/`Keyword.merge` | hint |
| be-enum-map-filter-chain | 链式 `Enum.map`/`filter` | hint |
| be-io-puts-hot | 循环内 `IO.puts` / `io:format` | off |

仅在有 `evidence/be-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
