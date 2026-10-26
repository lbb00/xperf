# objcperf evidence

Measured 2026-10-22 (Asia/Shanghai) on **GNUstep**, not the Apple runtime.

- **oc-nsstring-append-in-loop** — measured (`oc-nsstring-append-in-loop.md` + `oc-nsstring-append-in-loop.jsonl`); default stays **off**.
- **oc-nslog-in-loop** — measured with an `fprintf` proxy (`oc-nslog-in-loop.md` + `oc-nslog-in-loop.jsonl`); default stays **off**.
- **oc-dateformatter-in-loop**, **oc-json-in-loop**, **oc-regex-in-loop** — measured JSONL, default **hint**; not corpus-triaged. See each slug md for the ratio and the shape limit.
- `OC001` and `OC004` are removed; tombstones are under `_removed/`.

Harness: `examples/bench/evidence_oc.m`. Policy: [`../docs/evidence-policy.md`](../docs/evidence-policy.md). Root matrix: [`../../../docs/rule-regression.md`](../../../docs/rule-regression.md).
