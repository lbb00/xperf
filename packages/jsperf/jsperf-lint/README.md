# jsperf-lint

Zero-dependency **Node / pure JS** heuristics over `.js` / `.mjs` / `.cjs` / `.ts` / `.tsx` (line windows; not a full parser).

## Rules (v0)

| ID | app | engine | all | Summary |
|----|-----|--------|-----|---------|
| jp-alloc-in-loop | **off** | **off** | error | `.push({` / non-empty binders / clear `new` / `Object.create` in a loop (G3 OK-idiom → off) |
| jp-console-in-loop | **off** | hint | error | `console.*` in a loop window |
| jp-delete-shape | **off** | **off** | error | `delete` on a plain member / computed key (G3 OK-idiom on Node → off) |
| jp-delete-array-hole | **error** | **error** | error | `delete arr[i]` — holey arrays (G4; narrowed index heuristic) |
| jp-map-filter-chain | **hint** | **hint** | error | chained `.map`/`.filter`/`.flatMap`; cost grows with length |
| jp-regex-ctor-in-loop | **hint** | **hint** | error | `new RegExp` in a loop when the pattern is not a loop binding |
| jp-json-in-loop | **hint** | **hint** | error | `JSON.parse` / `JSON.stringify` in a loop when the text is not a loop binding |
| jp-dom-query-in-loop | **hint** | **hint** | error | `querySelector` / `getElementById` in a loop when the selector is not a loop binding |
| jp-intl-datetimeformat-in-loop | **hint** | **hint** | error | `new Intl.DateTimeFormat` in a loop when locale and options are not a loop binding |
| jp-readfile-sync-in-loop | **hint** | **hint** | error | `readFileSync` in the loop body when the path is not a loop binding |
| jp-clock-in-loop | **hint** | **hint** | error | `Date.now` / `performance.now` in a tight loop with no `await` |
| jp-query-all-star | **hint** | **hint** | error | `querySelectorAll('*')` full-tree walk (also sees scripts inside `executeJavaScript` templates) |
| jp-execjs-in-timer | **hint** | **hint** | error | built `executeJavaScript` / `evaluate` script re-sent from `setInterval` / `setTimeout` |
| jp-clone-per-event | **hint** | **hint** | error | `structuredClone` / `JSON.parse(JSON.stringify(...))` on an event-like payload |

Loop **headers** (e.g. `for (const x of querySelectorAll(...))`) and **nested function/arrow bodies** defined inside a loop but called later are not treated as per-iteration smells. Path skips include `e2e/`, `playwright-report/`, and `*.test.*` / `*.spec.*`. Template-string scripts passed to `executeJavaScript` / `evaluate` are scanned.

Does **not** detect IC polymorphism, elements-kind at runtime, or deopts — see guide §4.5.

## Usage

```sh
node jsperf-lint/bin/jsperf-lint.js PATH... [--format text|json]
node jsperf-lint/bin/jsperf-lint.js PATH... --preset app|engine|all
node jsperf-lint/bin/jsperf-lint.js PATH... --severity jp-alloc-in-loop=error --severity jp-map-filter-chain=off
node jsperf-lint/bin/jsperf-lint.js PATH... --strict-hints
node jsperf-lint/bin/jsperf-lint.js PATH... --no-fail
```

Default **`--preset app`**. `--severity` overrides the preset. Text: `path:line: error jp-delete-array-hole: …`. JSON includes `"severity"`. Exit `1` only for **error** findings (hints print but exit `0` unless `--strict-hints`).

## Self-lint (mandatory dogfood)

```sh
cd packages/jsperf
npm run self-lint   # lints bin/ + lib/; must exit 0 with 0 findings
npm test            # fixtures + preset smoke
```

Dogfood corpora: `../docs/corpus.md` (trees are not shipped; clone locally). **Corpus-ready: yes** (2026-10-22 redesign).

## Evidence

Measured gates: `../evidence/jp-*.{md,jsonl}` (jp-delete-array-hole → **error**; jp-delete-shape demoted off after G3 despite JSONL; jp-map-filter-chain has JSONL and stays **hint** because a short array is a different cost). `jp-string-plus-in-loop` is removed. `jp-dom-query-in-loop` and `jp-intl-datetimeformat-in-loop` have JSONL and stay **hint** (not corpus-triaged; outside the 2026-10-22 verdict). Policy: [`../docs/evidence-policy.md`](../docs/evidence-policy.md).
