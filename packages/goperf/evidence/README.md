# goperf evidence

Per-rule `<slug>.md` + `<slug>.jsonl` for the original five rules (gp-make-hot–gp-defer-hot), measured with `examples/bench/evidence_gp.go`. `gp-regexp-compile-hot`, `gp-json-marshal-hot`, and `gp-reflect-hot` have JSONL microbenches and stay hint. `gp-reflect-hot` matches name lookup and `reflect.New` (a `TypeOf` rerun was about 1.3× and is not matched). `gp-time-parse-in-loop` was removed. Defaults are unchanged: gp-make-hot–gp-fmt-hot **off**, gp-append-nil-slice/gp-defer-hot **hint**.

See [`../docs/evidence-policy.md`](../docs/evidence-policy.md) and root [`docs/rule-regression.md`](../../../docs/rule-regression.md).
