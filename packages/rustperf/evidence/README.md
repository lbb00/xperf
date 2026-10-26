# rustperf evidence

All six rules have a claim file and measured JSONL (harnesses in [`../examples/bench`](../examples/bench)):

- **rs-alloc-in-loop** — `rs-alloc-in-loop.md` + `.jsonl`; Vec::new reuse ~2.7× / fixture clone ~1.1× / to_string ~1.7×; default **off** (modest ratios, G3 OK-idiom dominates).
- **rs-println-in-loop** — `rs-println-in-loop.md` + `.jsonl`; buffered write ~12.6× (I/O, environment-dependent); default **hint**.
- **rs-format-rebind-in-loop** — `rs-format-rebind-in-loop.md` + `.jsonl`; `format!` rebind ~99× (aliased from the rs-string-plus-in-loop G4 `format!` pair); default **error**.
- **rs-collect-vec-in-loop** — `rs-collect-vec-in-loop.md` + `.jsonl`; ~1.8×; default **hint**.

See [`../docs/evidence-policy.md`](../docs/evidence-policy.md) and root [`docs/rule-regression.md`](../../../docs/rule-regression.md).
