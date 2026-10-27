# rubyperf evidence

Each rule has a claim file and measured JSONL from `examples/bench/evidence_rb.rb`:

- `rb-string-plus-hot` — `.md` + `.jsonl`
- `rb-array-plus-rebind` — `.md` + `.jsonl`
- `rb-puts-hot` — `.md` + `.jsonl`
- `rb-hash-merge-in-loop` was removed; see `_removed/`

`rb-regexp-new-hot` and `rb-json-hot` have JSONL and stay **hint**. `rb-date-parse-in-loop` was removed; see `_removed/`.

Defaults and the escalation rule: [`../docs/evidence-policy.md`](../docs/evidence-policy.md) and root [`docs/rule-regression.md`](../../../docs/rule-regression.md).
