## 5. Startup and tooling (cold paths)

This chapter is about **tooling / cold-start / module-graph** cost — not the hot-loop shape and allocation smells in §1–§2 / §4.

Primary source: Marvin Hagemeister’s series **[Speeding up the JavaScript ecosystem](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)** (parts 1–13). Methods below are paraphrased; **do not treat his wall-clock numbers as ours** — re-measure on your machine.

| Concern | Chapters | What finds it |
|---------|----------|---------------|
| Runtime shape / alloc / holey / `delete` | §1, §2, §4 | the jp-* rules + `examples/bench` |
| Module resolution, eager `require`, barrels, CLI overhead | **§5** | `node --cpu-prof` / speedscope, require-graph inspection — **not** the jp-* rules |

### 5.1 Profile first (tooling)

Before rewriting a library or CLI:

1. Capture a CPU profile: `node --cpu-prof your-tool.js …` (or `node --cpu-prof $(which npm) run …` for npm scripts — see [part 4](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-4/)).
2. Open the `.cpuprofile` in [speedscope](https://www.speedscope.app/) (or Chrome DevTools).
3. Ask: is time in **your** hot function, or in **loading / resolving** modules, casting, regex, FS?

Marvin’s recurring method ([part 1](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/)): find a top frame → open source → remove avoidable work → re-profile. Same loop as XPerf’s “measure before rewrite,” aimed at **build/lint/CLI** rather than app render loops.

### 5.2 Hot casts, short-string regex, inner functions (part 1 methods)

Paraphrased patterns from [part 1](https://marvinh.dev/blog/speeding-up-javascript-ecosystem/) (PostCSS, SVGO, and neighbors):

- **String ↔ number churn** — e.g. `toFixed` then `+` back to number in a tight loop. Prefer staying in number-land (`Math.round` / scale by `10**p`).
- **Regex on many short strings** — matching one regex against many tiny serialized fragments is often worse than one pass over a longer string, or a cheap pre-check that the needle exists at all.
- **Functions created inside hot outer functions** — closures recreated every call hurt ICs; lift helpers or pass args explicitly instead of capturing.
- **Transpiler artifacts** — e.g. `for…of` rewritten into a fresh `_loop` function per iteration; inspect **published** output, not only source.

These can overlap §4 (ICs) when the path is hot at runtime. In tooling they often dominate **startup or per-file** cost instead.

### 5.3 Module resolution (part 2 methods)

From [part 2](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-2/): resolution can outweigh parsing in lint/test/build traces.

Adopt as checklist (paraphrase of his four takeaways):

1. **Avoid FS** — every `stat`/`exists` is expensive at scale.
2. **Cache** resolved paths (watch mode: invalidate carefully).
3. **`fs.statSync(path, { throwIfNoEntry: false })`** — avoid throwing + capturing stack traces for “file missing” (ENOENT path).
4. **Limit upward `node_modules` walks** — especially when path aliases are mistaken for bare package imports.

Also watch **extension guessing** (`.js` → `.jsx` → … → `.ts`) and alias plugins that do not share the same resolver as TypeScript/`tsconfig` paths.

**jsperf-lint cannot see this.** No jp-* rule measures FS or resolution. Companions: CPU profiles, resolver caches, and the eager-vs-lazy sketch in `examples/bench/require_cost_sketch.js`.

### 5.4 Startup: eager graph, barrels, “gorilla holding a banana”

From [part 4](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-4/) (npm scripts) and [part 7](https://marvinh.dev/blog/speeding-up-javascript-ecosystem-part-7/) (barrels):

- **Eager `require` / `import`** loads the whole reachable graph up front. Error formatters, audit code, progress bars — anything unused on the happy path — should be **lazy** (`require` inside the `if (err)` branch, dynamic `import()` for rare commands).
- **Fat classes / mixin piles** pull “the gorilla holding the banana and the entire jungle” (Joe Armstrong, via Marvin): one entry class that mixins audit + reify + rebuild when you only needed `run`.
- **Barrel files** (`index.js` that only `export * from …`) amplify the graph: one import can pull a folder tree; test runners that spawn per file pay the cost repeatedly. Prefer direct imports when startup or lint/test wall time matters.
- **Published bundle** for CLIs can shrink load cost; measure — giant single files have a parse tradeoff.

### 5.5 Relation to the jp-* rules

| | Runtime chapters (§1–§2, §4) | This chapter (§5) |
|--|----------------------------|-------------------|
| Typical win | Hot loop IC / GC / elements kind | Cold start, `npm run`, lint/test graph |
| Lint | the jp-* rules (line-window heuristics) | **None today** — document-only companions |
| Evidence | `examples/bench/*`, `--trace-deopt` | `--cpu-prof` + speedscope; require-graph size |

Do **not** interpret a clean jsperf-lint self-lint as “startup is fine.” Do **not** treat Marvin’s published speedups as transferable without a local profile.

### 5.6 Optional sketch: eager vs lazy require

`examples/bench/require_cost_sketch.js` builds a tiny fixture graph and times eager top-level `require` vs lazy `require` inside a rarely taken branch. It is a **teaching microbench**, not a claim about npm or your app. Run: `node examples/bench/require_cost_sketch.js`.

---

