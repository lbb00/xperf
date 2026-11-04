## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| sp-print-hot | 循环内 `print(` | off（相对 String 约 10×；丢弃 stdout） |
| sp-array-no-reserve | 空 Array 追加且无 `reserveCapacity` | hint（小约 5×，一次大填充约 1.6×） |
| sp-dateformatter-hot | 循环内构造 date formatter | hint（有 JSONL；未 corpus 分级） |
| sp-json-decode-hot | 循环内 JSON decoder 或 jsonObject | hint（有 JSONL；未 corpus 分级） |
| sp-regex-hot | 循环内构造正则 | hint（有 JSONL；未 corpus 分级） |

用 `--severity <rule>=hint` 启用 `off` 规则。2026-10-22 的五条规则仍无 JSONL。2026-10-23 新增三行有 JSONL 微基准并保持 **hint**。它们不属于 2026-10-22 corpus-ready 裁决。见 [evidence-policy.md](evidence-policy.md)。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
