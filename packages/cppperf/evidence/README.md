# cppperf evidence

Updated **2026-10-22** Asia/Shanghai.

`cx-string-append-unreserved` was removed (about 1.09×); the old JSONL is under `_removed/`. `cx-const-by-value` and `cx-vector-bool` were measured on 2026-10-23 and stay **hint**. The 2026-10-22 corpus verdict does not cover those two slugs. Default stays **hint**; no escalate to `error`. Retired rules keep tombstones and their old JSONL under `_removed/`.

See [`../docs/evidence-policy.md`](../docs/evidence-policy.md) and root [`docs/rule-regression.md`](../../../docs/rule-regression.md).
