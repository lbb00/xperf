# jsperf evidence policy

## Gate

A JP rule may be documented / treated as **`error`** only if both exist under `packages/jsperf/evidence/`:

1. `<RULE>.md` — claim, harness, Node/V8 versions, limits
2. `<RULE>.jsonl` — ≥1 before/after measurement pair with fields `rule`, `case`, `node`, `v8`, `median_ms`, `ops`, `ratio`, `ts` (optional `role`: `before` = smell, `after` = fix)

Otherwise the rule is **`hint`** (review prompt): fine for dogfood and fixtures, not a “must fix for speed” signal.

Evidence alone is **necessary, not sufficient** for `error`. Escalate only when wall-clock agrees **and** the failure mode matches the rule’s keep contract (shape / holey / hot `delete`). Alloc/GC or env-dependent I/O smells may keep **`hint`** / **`off`** even with JSONL.

## Current map

As of 2026-10-23. "Default" is the `app` preset; `--preset all` raises every rule to error.

| Rule | Default severity | Evidence | Measured ratio (Node v20.19.2 / V8 11.3.244.8-node.38) |
|------|----------|----------|--------------------------------------------------|
| jp-delete-shape | **off** | [jp-delete-shape.md](../evidence/jp-delete-shape.md) · [jp-delete-shape.jsonl](../evidence/jp-delete-shape.jsonl) | `delete` / tombstone **~474×**; JSONL exists, but corpus triage found the hits almost all OK-idiom → **off**; enable with `--preset all` / `--severity jp-delete-shape=error` |
| jp-delete-array-hole | **error** | [jp-delete-array-hole.md](../evidence/jp-delete-array-hole.md) · [jp-delete-array-hole.jsonl](../evidence/jp-delete-array-hole.jsonl) | holey `delete a[i]` / packed **~3.2×** |
| jp-alloc-hot | **off** (default) | [jp-alloc-hot.md](../evidence/jp-alloc-hot.md) · [jp-alloc-hot.jsonl](../evidence/jp-alloc-hot.jsonl) | JSONL ~19×/~6.4× exists; G3 corpora almost-all OK-idiom → **off**; enable with `--preset all` / `--severity jp-alloc-hot=hint` |
| jp-console-hot | **hint** (`engine`) / **off** (`app`) | [jp-console-hot.md](../evidence/jp-console-hot.md) · [jp-console-hot.jsonl](../evidence/jp-console-hot.jsonl) | `console.log` in-loop / quiet **~1328×** (discard sink) — real but env-dependent → not error |

| jp-string-plus-in-loop | **removed** | [tombstone](../evidence/_removed/jp-string-plus-in-loop.REMOVED.md) | `push` + `join` was not ~2× on the matched shapes; matcher deleted |
| jp-map-filter-chain | **hint** | [jp-map-filter-chain.md](../evidence/jp-map-filter-chain.md) · [jsonl](../evidence/jp-map-filter-chain.jsonl) | 35000 rows about 4.6× / 9.8×; a 3-row filter+map is 1.28×; stay hint |
| jp-regex-ctor-hot | **hint** | measured (`jp-regex-ctor-hot.md` + `jp-regex-ctor-hot.jsonl`); stay hint | `new RegExp` (stable pattern); not corpus-triaged |
| jp-json-hot | **hint** | measured (`jp-json-hot.md` + `jp-json-hot.jsonl`); stay hint | `JSON.parse` / `stringify` (stable text); not corpus-triaged |
| jp-dom-query-hot | **hint** | measured (`jp-dom-query-hot.md` + `jp-dom-query-hot.jsonl`); stay hint | DOM query (stable selector); about 16× on Node 26, a tiny linkedom document |
| jp-intl-datetimeformat-hot | **hint** | measured (`jp-intl-datetimeformat-hot.md` + `jp-intl-datetimeformat-hot.jsonl`); stay hint | `new Intl.DateTimeFormat`; Node 26 about 36×; not corpus-triaged |
| jp-readfile-sync-hot | **hint** | measured (`jp-readfile-sync-hot.md` + `jp-readfile-sync-hot.jsonl`); stay hint | `readFileSync` (stable path); not corpus-triaged |
| jp-clock-hot | **hint** | measured (`jp-clock-hot.md` + `jp-clock-hot.jsonl`); stay hint | `Date.now` / `performance.now`; not corpus-triaged |

Hint text states the measured premise (unchanged path, text, pattern, selector, or formatter; a tight loop with no `await` for the clock). A rule with no JSONL does not name a replacement. A call that only looks like the bench is not given the bench's rewrite. This policy is the **keep / escalate** contract for guides and `--preset`.

## Regenerating

```sh
cd packages/jsperf
bash scripts/regen-evidence.sh
# or:
# node examples/bench/evidence_jp003_jp004.js
# node examples/bench/evidence_jp001_jp002.js
# node examples/bench/evidence_jp005_jp006.js
```

Re-run after Node major upgrades; update the matching `.md` tables.

## CLI presets

- Default `--preset app`: **jp-delete-array-hole=error**; **jp-map-filter-chain**, **jp-regex-ctor-hot**, **jp-json-hot**, **jp-dom-query-hot**, **jp-intl-datetimeformat-hot**, **jp-readfile-sync-hot**, and **jp-clock-hot** = hint; **jp-alloc-hot**, **jp-console-hot**, **jp-delete-shape** = off (G3 2026-10-22 for the off rules). **jp-string-plus-in-loop** is removed.
- `engine`: same as `app`, except **jp-console-hot** = hint.
- `all`: every rule is error.
- Overrides: `--severity RULE=error|hint|off` (repeatable; wins over the preset).
