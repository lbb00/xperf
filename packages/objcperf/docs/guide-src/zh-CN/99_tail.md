## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| oc-nsstring-append-hot | 循环内 stringByAppendingString | off |
| oc-nslog-hot | 循环内 NSLog | off |
| oc-dateformatter-hot | 循环内 date formatter alloc/init 或 new | hint（有 JSONL；未 corpus 分级） |
| oc-json-hot | 循环内 JSON 解析或编码 | hint（有 JSONL；未 corpus 分级） |
| oc-regex-hot | 循环内编译正则 | hint（有 JSONL；未 corpus 分级） |

仅在有 `evidence/oc-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。两条数组容量规则（OC001、OC004）已移除；见 [rule-ids.md](rule-ids.md)。`oc-dateformatter-hot`、`oc-json-hot`、`oc-regex-hot` 有 JSONL 微基准并保持 hint。它们不属于 2026-10-22 corpus-ready 裁决。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
- [swiftperf](../../../swiftperf/)（同级）
