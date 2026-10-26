# kotlinperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.

## Pins

| Tree | URL | Commit | Size | Lint scope |
|------|-----|--------|------|------------|
| kotlinx.coroutines | https://github.com/Kotlin/kotlinx.coroutines.git | `7e0d1b3e9ca83652427ae00dda7d1673f058a743` | ~27M | whole tree |
| okhttp | https://github.com/square/okhttp.git | `2657315344316ba5bd1292d2fe9ca12636ae2290` | ~15M | whole tree (Kotlin sources) |
| kotlinx.serialization | https://github.com/Kotlin/kotlinx.serialization.git | `4c28c3e33c145da536f1f4a671f70e5eb5b62b9c` | ~13M | whole tree |

Shallow clones (`--depth 1`).

## Dogfood (2026-10-21 Asia/Shanghai)

| Tree | Raw (`--raw-paths`) | After reverse-opt |
|------|---------------------|-------------------|
| kotlinx.coroutines | **84** (kt-list-add-in-loop:2 kt-string-plus-in-loop:6 kt-println-in-loop:76) | **6** (1/5/0) |
| okhttp | **29** (11/1/17) | **8** (5/0/3) |
| kotlinx.serialization | **4** (2/0/2) | **1** (1/0/0) |

Rule order: kt-list-add-in-loop / kt-string-plus-in-loop / kt-println-in-loop.

### Reverse-opt (`kotlinperf-lint`)

1. **`--raw-paths`:** baseline toggle.
2. **Path skips:** `test/` `tests/` `androidTest/` `jvmTest/` `commonTest/` `nativeTest/` `benchmarks/` `samples/` `sample/` `examples/` `example/` `docs/` (plus always `.git`/`build`/`.gradle`/`vendor`/`fixtures`).
3. **Path suffixes:** `*Test.kt` / `*Tests.kt` / `/src/test/`.
4. **kt-list-add-in-loop:** suppress bare empty `listOf()` under reverse-opt (keep `mutableListOf` / `arrayListOf` / `ArrayList()`).
5. **kt-println-in-loop:** skip KDoc/block-comment continuation lines (`* … println`); skip Debug/Demo filenames and `DEBUG` tokens.

### Residual

- coroutines: a few real `+=` string builders in guidance/examples that live outside skipped dirs.
- okhttp: list allocs in hot decoder paths (signal).

Do not commit corpus sources into `packages/kotlinperf`.

## G3 TP/FP triage (2026-10-22 Asia/Shanghai)

| | r1 sample n=15 | r2 sample n=3 |
|--|----------------|---------------|
| TP | 0% | 0% |
| FP | 40% | 0% |
| OK-idiom | 46.7% | **100%** |
| SKIP-path | 13.3% | 0% |
| **FP+DOC+SKIP** | **53.3%** | **0%** |

**Corpus-ready? `no`** — r1 noise >40%; r2 all OK-idiom (lazy lists / rare-race). Keep rules **hint**.

### Fixes landed
- kt-string-plus-in-loop collection `+=` suppression; kt-println-in-loop bare `println` only; kt-list-add-in-loop lazy/constant listOf
- Path skips: `test-utils/`, `testing-support/`, `rules-integration-tests/`, `okcurl/`
- r2 counts: coroutines **1**, okhttp **2**, serialization **0**

## Redesign → corpus-ready (2026-10-22 Asia/Shanghai)

| Tree | r2 | r3 (defaults) | corpus-ready? |
|------|----|---------------|---------------|
| kotlinx.coroutines | 1 | **2** | |
| okhttp | 2 | **9** | |
| kotlinx.serialization | 0 | **1** | |

**Verdict: corpus-ready `yes`.** Sample n=12: TP 58.3% / OK-idiom 41.7% / FP+DOC+SKIP 0%. Defaults: kt-list-add-in-loop–kt-println-in-loop **off**. KT004 removed (jitter; it covered empty list + add in size-hinted loop). No G4 escalate / no invented JSONL.
