# rubyperf 证据

每条规则都有一个索赔文件和从 `examples/bench/evidence_rb.rb` 测量的 JSONL：

- `rb-string-plus-hot` — `.md` + `.jsonl`
- `rb-array-plus-rebind` — `.md` + `.jsonl`
- `rb-puts-hot` — `.md` + `.jsonl`
- `rb-hash-merge-in-loop` 已被移除；请参见 `_removed/`

`rb-regexp-new-hot` 和 `rb-json-hot` 拥有 JSONL 并保持 **提示**。`rb-date-parse-in-loop` 已被移除；请参见 `_removed/`。

默认值和升级规则：[`../docs/evidence-policy.md`](../../docs/zh-CN/evidence-policy.md) 和根目录 [`docs/rule-regression.md`](../../../../docs/zh-CN/rule-regression.md)。
