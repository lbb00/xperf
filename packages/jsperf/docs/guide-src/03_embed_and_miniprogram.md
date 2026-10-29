## 3. Embed and 小程序

### 3.1 Same physics, smaller runtime

QuickJS, Hermes-like embeds, and 小程序 JS runtimes still pay for:

- Per-iteration object allocation (jp-alloc-hot patterns).
- Shape changes via `delete` or divergent property order.
- Logging in tight loops (**jp-console-hot** — `console.log` / `console.debug`). Evidence: [`jp-console-hot`](../evidence/jp-console-hot.md) (~**1300×** vs quiet even with discarded stdout) — default **off** (`app`) / **hint** (`engine`), not a CI error.

They often **lack** a browser Performance panel, DOM, or large IC budgets. Advice that starts with “open DevTools → …” does not transfer. Prefer:

- Alloc/shape discipline from §1–§2.
- Batching work (`examples/p02_batch_note.js`) instead of per-item microtasks when the host exposes a batch API.
- Measuring with the **host** profiler (Node `--prof`, QuickJS timing hooks, vendor 小程序 perf panels) — not Chrome-only workflows.

**Do not** apply §4 (Maglev/Turbofan, elements-kind transitions, `--trace-deopt`) to these runtimes. Stable shapes and fewer allocs still help; V8 tier talk does not.

### 3.2 Shared quickjs tree

cperf dogfoods the **C** engine; jsperf dogfoods the `*.js` beside it (tests and `gen-*` skipped). The current rules report **0** findings there ([corpus.md](corpus.md)); earlier revisions reported 2 jp-alloc-hot. Low pressure, but useful as an embed-adjacent sample. Do not expect Preact-level cleanliness on generator scripts.

### 3.3 What not to recommend here

- DOM batching / `requestAnimationFrame` as the primary fix.
- `innerHTML` vs `createElement` debates.
- Browser-only APIs (`WeakRef` + FinalizationRegistry patterns that the embed may not ship).
- Turbofan / Maglev / elements-kind tuning from §4.

Typed arrays and consistent shapes remain portable (`examples/p01_typed_array.js`, `m01_hidden_class.js`).

---

