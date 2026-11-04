# objcperf 证据

测量于 2026-10-22（亚洲/上海）在 **GNUstep** 上，而不是苹果运行环境上。

- **oc-nsstring-append-hot** — 已测量（`oc-nsstring-append-hot.md` + `oc-nsstring-append-hot.jsonl`）；默认保持 **关闭**。
- **oc-nslog-hot** — 使用 `fprintf` 代理测量（`oc-nslog-hot.md` + `oc-nslog-hot.jsonl`）；默认保持 **关闭**。
- **oc-dateformatter-hot**、**oc-json-hot**、**oc-regex-hot** — 测量 JSONL，默认 **提示**；未进行语料库筛选。有关比率和形状限制，请参见各自的 md 文件。
- `OC001` 和 `OC004` 已删除；墓碑文件位于 `_removed/` 下。

挂载点：`examples/bench/evidence_oc.m`。策略：[`../docs/evidence-policy.md`](../../docs/zh-CN/evidence-policy.md)。根矩阵：[`../../../docs/rule-regression.md`](../../../../docs/zh-CN/rule-regression.md)。
