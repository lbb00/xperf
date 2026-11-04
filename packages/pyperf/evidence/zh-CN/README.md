# pyperf 证据

2026-10-22 规则已经测量了填充（`<slug>.md` + `<slug>.jsonl`，使用 `examples/bench/evidence_pp.py`）。没有被升级：pp-str-plus-hot 和 pp-print-hot 保持 **关闭**，pp-list-plus-rebind 保持 **提示**。

`pp-json-hot` 和 `pp-deepcopy-hot` 有 JSONL 并保持 **hint**。`pp-regex-compile-in-loop` 和 `pp-datetime-format-in-loop` 已被移除；请参见 `_removed/`。

`PP004` 墓碑位于 `_removed/` 下。

请参阅 [`../docs/evidence-policy.md`](../../docs/zh-CN/evidence-policy.md) 和根目录下的 [`docs/rule-regression.md`](../../../../docs/zh-CN/rule-regression.md)。
