### Lint map

| ID | Topic | Severity | Evidence / note |
|----|--------|----------|-----------------|
| jp-alloc-in-loop | object/array/`new` alloc | **off** (`all`: error) | [`jp-alloc-in-loop`](../evidence/jp-alloc-in-loop.md) ~19× / ~6.4× — GC/alloc, not deopt |
| jp-console-in-loop | `console.*` | **hint** (`engine`) / **off** (`app`) | [`jp-console-in-loop`](../evidence/jp-console-in-loop.md) ~1328× discard sink — env-dependent |
| jp-delete-shape | `delete` on plain members | **off** (`all`: error) | [`jp-delete-shape`](../evidence/jp-delete-shape.md) ~474× vs tombstone; corpus hits almost all OK-idiom |
| jp-delete-array-hole | `delete` with computed index (holey arrays) | **error** | [`jp-delete-array-hole`](../evidence/jp-delete-array-hole.md) ~3.2× vs packed |
| jp-map-filter-chain | chained `.map` / `.filter` / `.flatMap` | **hint** | long arrays about 4.6×–9.8×; a 3-row filter+map is 1.28× |
| jp-regex-ctor-in-loop | `new RegExp`, pattern not a loop binding | **hint** | Node 26 fixed pattern about 4.4×; prefer a literal or one shared compile |
| jp-json-in-loop | `JSON.parse` / `stringify`, text not a loop binding | **hint** | Node 26 one unchanged text about 140×; reuse when stable |
| jp-dom-query-in-loop | DOM query, selector not a loop binding | **hint** | JSONL about 16× on Node 26, a tiny linkedom document; not corpus-triaged |
| jp-intl-datetimeformat-in-loop | `new Intl.DateTimeFormat` | **hint** | Node 26 about 36×; both sides still format; not corpus-triaged |
| jp-readfile-sync-in-loop | `readFileSync`, path not a loop binding | **hint** | Node 26, one unchanged path about 114× |
| jp-clock-in-loop | `Date.now` / `performance.now` | **hint** | Node 26 about 70× / 110× with no `await`; sample once when fresh time is not required |
| *(none)* | module resolution / eager graph / barrels | — | §5 — use `--cpu-prof` |

Severities above are the default `app` preset. Matching scope defaults to **`--scope all`** (everywhere); `--scope loop` restores in-loop-only matching. Policy: [`evidence-policy.md`](evidence-policy.md). Fixtures: `jsperf-lint/fixtures/{bad,good}/`.

### References

- [corpus.md](corpus.md)
- `examples/bench/` · `scripts/run-v8-benches.sh` · `scripts/jit-check.sh` · `scripts/run-static-vs-v8.sh` · `scripts/regen-evidence.sh` · `examples/bench/require_cost_sketch.js`
- [XPerf playbook](../../../docs/playbook.md)
- Marvin Hagemeister — [Speeding up the JavaScript ecosystem](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/) (parts 1–13; methods cited in §5)
