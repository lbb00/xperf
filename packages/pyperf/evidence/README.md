# pyperf evidence

The 2026-10-22 rules have measured fills (`<slug>.md` + `<slug>.jsonl`, harness `examples/bench/evidence_pp.py`). None is escalated: pp-str-plus-in-loop and pp-print-in-loop stay **off**, pp-list-plus-rebind stays **hint**.

`pp-json-in-loop` and `pp-deepcopy-in-loop` have JSONL and stay **hint**. `pp-regex-compile-in-loop` and `pp-datetime-format-in-loop` were removed; see `_removed/`.

The `PP004` tombstone is under `_removed/`.

See [`../docs/evidence-policy.md`](../docs/evidence-policy.md) and root [`docs/rule-regression.md`](../../../docs/rule-regression.md).
