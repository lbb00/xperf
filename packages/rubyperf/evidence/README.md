# rubyperf evidence

Each rule has a claim file and measured JSONL from `examples/bench/evidence_rb.rb`:

- `rb-string-plus-in-loop` — `.md` + `.jsonl`
- `rb-array-plus-rebind` — `.md` + `.jsonl`
- `rb-puts-in-loop` — `.md` + `.jsonl`
- `rb-hash-merge-in-loop` was removed; see `_removed/`

`rb-regexp-new-in-loop` and `rb-json-in-loop` have JSONL and stay **hint**. `rb-date-parse-in-loop` was removed; see `_removed/`.

Defaults and the escalation rule: [`../docs/evidence-policy.md`](../docs/evidence-policy.md) and root [`docs/rule-regression.md`](../../../docs/rule-regression.md).
