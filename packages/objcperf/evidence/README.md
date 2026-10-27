# objcperf evidence

Measured 2026-10-22 (Asia/Shanghai) on **GNUstep**, not the Apple runtime.

- **oc-nsstring-append-hot** — measured (`oc-nsstring-append-hot.md` + `oc-nsstring-append-hot.jsonl`); default stays **off**.
- **oc-nslog-hot** — measured with an `fprintf` proxy (`oc-nslog-hot.md` + `oc-nslog-hot.jsonl`); default stays **off**.
- **oc-dateformatter-hot**, **oc-json-hot**, **oc-regex-hot** — measured JSONL, default **hint**; not corpus-triaged. See each slug md for the ratio and the shape limit.
- `OC001` and `OC004` are removed; tombstones are under `_removed/`.

Harness: `examples/bench/evidence_oc.m`. Policy: [`../docs/evidence-policy.md`](../docs/evidence-policy.md). Root matrix: [`../../../docs/rule-regression.md`](../../../docs/rule-regression.md).
