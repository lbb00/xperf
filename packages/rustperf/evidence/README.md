# rustperf evidence

All six rules have a claim file and measured JSONL (harnesses in [`../examples/bench`](../examples/bench)):

- **rs-alloc-hot** — `rs-alloc-hot.md` + `.jsonl`; Vec::new reuse ~2.7× / fixture clone ~1.1× / to_string ~1.7×; default **off** (modest ratios, G3 OK-idiom dominates).
- **rs-println-hot** — `rs-println-hot.md` + `.jsonl`; buffered write ~12.6× (I/O, environment-dependent); default **hint**.
- **rs-format-rebind-hot** — `rs-format-rebind-hot.md` + `.jsonl`; `format!` rebind ~99× (aliased from the rs-string-plus-in-loop G4 `format!` pair); default **error**.
- **rs-collect-vec-hot** — `rs-collect-vec-hot.md` + `.jsonl`; ~1.8×; default **hint**.

See [`../docs/evidence-policy.md`](../docs/evidence-policy.md) and root [`docs/rule-regression.md`](../../../docs/rule-regression.md).
