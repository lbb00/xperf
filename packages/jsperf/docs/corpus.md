# jsperf corpus targets

Working shortlist: engines + hot-path libs over random npm packages.
Trees are not shipped with the repo; clone them to any local directory outside the repo (the quickjs JS tree is shared with the C kit).

```sh
node jsperf-lint/bin/jsperf-lint.js <path-to-clone> --format json --no-fail
```

Checker: **jsperf-lint**.

## Pins

| Tree | URL | Commit | Scope |
|------|-----|--------|-------|
| Node | https://github.com/nodejs/node | `796a83a7` | shallow; `lib/**/*.js` |
| Preact | https://github.com/preactjs/preact | `74df25e` | `src/` |
| quickjs | shared with the C kit — see [cperf corpus](../../cperf/docs/corpus.md) | `7d1c13c` | `*.js` (`gen-*` skipped) |
| TypeScript | https://github.com/microsoft/TypeScript | `538671d3c` | `packages/typescript/src` |

## Corpus-ready?

**yes** — post-redesign G3 2026-10-22 (Asia/Shanghai). Default residuals **31× jp-string-plus-in-loop**
(22 TP / 9 OK-idiom). FP+DOC+SKIP **0%**. jp-delete-shape→`off` (was 100% OK-idiom). Triage notes are not shipped (post-redesign).

jp-delete-array-hole stays **error** (G4). On that day jp-string-plus-in-loop and jp-map-filter-chain defaulted to **hint** (string-plus was removed 2026-10-23; see below). jp-alloc-hot/jp-console-hot/jp-delete-shape default **off**.

## Cloned — g3e (2026-10-22 redesign)

| Tree | Size | Findings g3c → g3e |
|------|------|--------------------|
| **Node `lib/`** | ~7M `lib/` | **38 jp-delete-shape → 29 jp-string-plus-in-loop** |
| **Preact `src/`** | 3.3M | **0 → 0** |
| **quickjs JS** | (shared) | **0 → 0** |
| **TypeScript** | src 1.9M | **0 → 2** jp-string-plus-in-loop |

G3 redesign: jp-delete-shape→off; jp-string-plus-in-loop string-append-in-loop; jp-map-filter-chain map/filter chain; cold formatter + gen-file skips.

Dir skips: `node_modules`, `.git`, `dist`, `coverage`, `tests`, `test`, `benchmarks`, `demo`, `fixtures`.
File skips: `gen-*`, `*generate*`, `diagnosticFormatter.ts`.
jp-string-plus-in-loop and jp-map-filter-chain also skip inspect/debugger/test_runner/reporter/bench_runner/assert/myers_diff/cli_table paths.

## Clone order

1. **Done:** Node `lib/` + Preact + quickjs JS + TypeScript `packages/typescript/src`
2. Later: older TS tag with large `src/compiler`, Solid / lodash-es

## Mini-program / embed focus

Keep guide advice usable for **embed JS and 小程序-like** runtimes (QuickJS).

## Inventory

```text
<corpus-dir>/
  node/
  preact/
  TypeScript/
  quickjs/   # shared with the C kit
```

## 2026-10-23 — hint rules outside the 2026-10-22 verdict

The 2026-10-22 corpus-ready verdict does not cover the slugs below. They stay **hint** and have not been through G2/G3.

- `jp-regex-ctor-hot`, `jp-json-hot` — JSONL on disk; still hint. A pattern or text that is the loop binding is not reported.
- `jp-dom-query-hot`, `jp-intl-datetimeformat-hot` — JSONL on disk; still hint. A selector, locale, or options value that is the loop binding is not reported.
- `jp-readfile-sync-hot`, `jp-clock-hot` — JSONL on disk; still hint. The `for` iterable is not the body. A loop that `await`s is not the clock bench.
- `jp-map-filter-chain` — JSONL on disk; still hint. Long arrays were about 4.6×–9.8×; a 3-row filter+map was 1.28×.
- `jp-string-plus-in-loop` — removed the same day. The 2026-10-22 residual counts above are historical. The matcher no longer runs, and those trees were not re-linted for this note.
