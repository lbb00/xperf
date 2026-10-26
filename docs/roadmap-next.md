# XPerf — what else (same playbook)

Derived from the closed loop: **guide ↔ measured evidence ↔ corpus dogfood ↔ reverse-opt ↔ impl in the target language ↔ honest limits**.

## Already proven (keep)

- Same-language checkers (Zig / C / JS) + self-lint = 0.
- Corpus reverse-opt improves **precision**, not app speed by itself.
- Static smell ↔ runtime: **partial** (jsperf STATIC-VS-V8; **cperf STATIC-VS-O2**); must re-validate per rule family.
- Cross-kit catalog: [smell-catalog.md](smell-catalog.md).
- Engine corpora (gcc/Node) are weak as “find speedups”; strong as FP mills.

## High leverage next

### 1. Finding → bench gate (**jp-delete-shape / jp-delete-array-hole / cp-alloc-in-loop done**)
Every **kept** rule needs ≥1 fixture pair with JSONL before/after on a named runtime (cc -O2 / Node version / Zig ReleaseFast).
Ship as `packages/*/evidence/<rule-id>.jsonl` + guide citation.
Until then, treat lint as review prompt only (already true; make it mechanical).

### 2. Severity / modes (**done** in cperf/jsperf)
- `error`: only rules with measured agreement (e.g. jsperf jp-delete-array-hole, cperf cp-alloc-in-loop).
- `hint` / off-by-default: cp-printf-in-loop, jp-console-in-loop, jp-alloc-in-loop.
- Profiles: `--preset app|engine|all` + `--severity RULE=…` + `--strict-hints`.

### 3. Dynamic companions (not more static rules)
| Kit | Companion | Purpose |
|-----|-----------|---------|
| jsperf | `--trace-deopt` / Perf harness (started) | JIT truth |
| cperf | `perf stat` / cachegrind wrapper on examples | I/O vs alloc myths |
| zperf | existing benches + tracy optional | keep |
| jvmperf | JMH + EaProbe / `STATIC-VS-HOTSPOT` (started) | HotSpot wall-clock & B/op; not PrintCompilation counts |

Static answers “might hurt”; dynamic answers “did hurt here”.

### 4. Own hot code, not only upstream engines
Point corpora at **user/product trees** (and mini-program / embed JS for jsperf).
Success metric: actionable TPs with benches, not residual count ↓.

### 5. Cross-kit “same smell, three languages” (**catalog landed**)
See [smell-catalog.md](smell-catalog.md). Fill empty cells (C layout rules) as rules appear.
Forces honest portability claims (V8 ≠ QuickJS ≠ C).

### 6. jvmperf slot
**Landed** under `packages/jvmperf/` (`jvmperf-lint`, guides, JMH). Evidence gate + correlate: `docs/evidence-policy.md`.

### 7. CI dogfood
`make self-lint` / `npm run self-lint` / `zig build` on PR; corpus lint **nightly** on pinned SHAs (not every commit).

### 8. Negative results as first-class docs
Publish negatives as first-class docs — jsperf STATIC-VS-V8 + **cperf STATIC-VS-O2** (`#if 0` cp-printf-in-loop) done; keep extending.

## Explicit non-goals (for now)

- Full AST/typechecker-grade analysis.
- Claiming engine lint totals = performance wins.
- Detecting JIT tier / IC state from source alone.

## Suggested order

1. ~~Severity split + app preset (c/js)~~ — **done**.
2. ~~Evidence JSONL for jp-delete-shape / jp-delete-array-hole / cp-alloc-in-loop~~ — **done**; see each kit's `evidence/`.
3. One product/embed corpus instead of more gcc.
4. ~~cperf static vs `-O2`~~ — **done** (correlation suite kept outside the repo).
5. ~~Cross-kit smell catalog stub~~ — **done**: [smell-catalog.md](smell-catalog.md); fill remaining evidence cells.
6. Dynamic companions (`perf stat` on cperf examples).
