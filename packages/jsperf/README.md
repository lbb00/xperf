# jsperf

JavaScript/TypeScript performance notes aimed at V8/Node and embeds (QuickJS / 小程序-like): hidden classes, elements kinds, GC pressure, typed arrays, async batching, and avoiding polymorphic hot paths.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). The lint is **pure JS** (Node ≥18, zero npm deps) with severity presets. Guide v0 includes **§4 V8 optimizations** (single-machine microbenches, Node 22.22.3) and **§5 startup/tooling** (Marvin series methods).

## Contents

- [English guide (v0)](docs/js-performance-guide.md) — from `docs/guide-src/` (incl. `04_v8_optimizations`, `05_startup_and_tooling`)
- [`jsperf-lint`](jsperf-lint/README.md) — jp-* rules
- [Evidence policy](docs/evidence-policy.md) · [Rule ids](docs/rule-ids.md)
- [Corpus pins](docs/corpus.md)
- V8 benches: `examples/bench/` · `scripts/run-v8-benches.sh`

## Run lint

```sh
node jsperf-lint/bin/jsperf-lint.js path/to/sources --preset app   # default
node jsperf-lint/bin/jsperf-lint.js path/to/sources --preset all
node jsperf-lint/bin/jsperf-lint.js path/to/sources --scope all|loop   # default all
node jsperf-lint/bin/jsperf-lint.js path/to/sources --severity jp-alloc-hot=error
npm run self-lint   # dogfood own sources; must exit 0
npm test            # fixtures + preset smoke
```

Default **app**: jp-delete-array-hole = error; jp-map-filter-chain, jp-regex-ctor-hot, jp-json-hot, jp-dom-query-hot, jp-intl-datetimeformat-hot, jp-readfile-sync-hot, and jp-clock-hot = hint; jp-alloc-hot, jp-console-hot, and jp-delete-shape = off. Default **`--scope all`** reports those smells outside loops too (opt in to `--scope loop` for the former in-loop-only match). jp-string-plus-in-loop is removed. Exit `1` only for error-severity findings.

Evidence JSONL gates: [`evidence/`](evidence/) (jp-alloc-hot, jp-console-hot, jp-delete-shape, jp-delete-array-hole). Policy: [`docs/evidence-policy.md`](docs/evidence-policy.md). Regen: `bash scripts/regen-evidence.sh`.

## Layout

| Path | Contents |
|------|----------|
| `docs/` | guide (`guide-src/` is the source), corpus pins, evidence policy, rule ids |
| `evidence/` | per-rule evidence notes and JSONL |
| `examples/` | illustrative snippets; `examples/bench/` holds the V8 microbenches |
| `jsperf-lint/` | linter source, fixtures, README |
| `scripts/` | smoke test, bench and evidence runners |

## Examples / benches

```sh
node examples/m01_hidden_class.js
node examples/p01_typed_array.js
# Prefer Node 22+ for §4 numbers:
NODE_BIN=$(command -v node) bash scripts/run-v8-benches.sh
NODE_BIN=$(command -v node) bash scripts/jit-check.sh          # --trace-deopt sample
NODE_BIN=$(command -v node) bash scripts/run-static-vs-v8.sh   # smell vs wall-clock
```
