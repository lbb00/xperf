# goperf evidence

Per-rule `<slug>.md` + `<slug>.jsonl` for the original five rules (gp-make-in-loop–gp-defer-in-loop), measured with `examples/bench/evidence_gp.go`. `gp-regexp-compile-in-loop`, `gp-json-marshal-in-loop`, and `gp-reflect-in-loop` have JSONL microbenches and stay hint. `gp-reflect-in-loop` matches name lookup and `reflect.New` (a `TypeOf` rerun was about 1.3× and is not matched). `gp-time-parse-in-loop` was removed. Defaults are unchanged: gp-make-in-loop–gp-fmt-in-loop **off**, gp-append-nil-slice/gp-defer-in-loop **hint**.

See [`../docs/evidence-policy.md`](../docs/evidence-policy.md) and root [`docs/rule-regression.md`](../../../docs/rule-regression.md).
