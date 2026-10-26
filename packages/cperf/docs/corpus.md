# cperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter. Lint with:

```sh
cd packages/cperf/cperf-lint && make
./cperf-lint <corpus-dir>/<name> --format json --no-fail
```

Checker is **C11** (`cperf-lint`). Former Python prototype removed.

## Pins

Cloned for the 2026-10-22 redesign (g3f).

| Tree | Commit | Size | Lint g3c → g3f (default) |
|------|--------|------|--------------------------|
| **quickjs** | `7d1c13c` shallow | 7.8M | **0 → 2** cp-strlen-in-cond |
| **lua** | `8cb93ba` shallow | 2.7M | **0 → 0** |
| **gcc** (sparse) | `152e0cc` | 176M | **5 → 7** (cp-strlen-in-cond:2 cp-alloc-in-loop:5) |
| **sqlite** | `0498915` sparse | 14M | **0 → 0** |

Path skips unchanged (r3 + G3). New: cp-strlen-in-cond strlen-in-cond; cp-strcat-in-loop strcat-in-loop (off).

## Corpus-ready?

**yes** — post-redesign G3 2026-10-22 (Asia/Shanghai). Default residuals **9**
(cp-strlen-in-cond×4 TP + cp-alloc-in-loop×5 with 1 TP / 4 OK-idiom). FP+DOC+SKIP **0%**. Honest TP from
**cp-strlen-in-cond** (`strlen` in loop condition).

cp-alloc-in-loop/cp-realloc-grow-one stay **error** (G4 JSONL). cp-printf-in-loop/cp-strcat-in-loop default **off**. cp-strlen-in-cond default **hint**.

## Primary

| Tree | Status |
|------|--------|
| quickjs | **done** (2× cp-strlen-in-cond TP) |
| gcc sparse | **done** (cp-strlen-in-cond TP + cp-alloc-in-loop mix) |
| sqlite | **done** (clean on default) |
| V8 | deferred (C++ / clang AST) |

## Secondary

| Tree | Status |
|------|--------|
| lua | **done** (clean) |
| redis / libuv / musl | later |

## Inventory

```text
<corpus-dir>/
  quickjs/
  lua/
  gcc/            # sparse
  sqlite/         # sparse src/
```

Do not commit corpus sources into `packages/cperf`.

## 2026-10-23 — new hint rules, not triaged

`cp-sprintf-in-loop`, `cp-fopen-in-loop`, `cp-gettime-in-loop`, and `cp-wide-bool-flags` are **hint**. Each has a JSONL microbench and has not been through G2/G3. `cp-regex-in-loop` is **hint** and has JSONL (about 9.7×). None of these slugs are part of the 2026-10-22 corpus-ready verdict above.
