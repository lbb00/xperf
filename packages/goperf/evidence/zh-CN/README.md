# goperf 证据

每条规则 `<slug>.md` + `<slug>.jsonl` 针对原来的五条规则（gp-make-hot–gp-defer-hot），通过 `examples/bench/evidence_gp.go` 测量。`gp-regexp-compile-hot`、`gp-json-marshal-hot` 和 `gp-reflect-hot` 有 JSONL 微基准测试并保持提示状态。`gp-reflect-hot` 匹配名称查找和 `reflect.New`（一次 `TypeOf` 重跑约为 1.3×，不算作匹配）。`gp-time-parse-in-loop` 已移除。默认值保持不变：gp-make-hot–gp-fmt-hot **关闭**，gp-append-nil-slice/gp-defer-hot **提示**。

请参阅 [`../docs/evidence-policy.md`](../../docs/zh-CN/evidence-policy.md) 和根目录下的 [`docs/rule-regression.md`](../../../../docs/zh-CN/rule-regression.md)。
