# csharpperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.

```sh
cd packages/csharpperf/csharpperf-lint && dotnet run -c Release -- <corpus-dir>/<name> --format json --no-fail
```

Checker: `csharpperf-lint`. Rules cs-list-add-no-capacity–cs-regex-in-loop.

## Pins

Cloned trees, r1/after → r2 → r3 (redesign). Commit pins were not recorded; record the commit when re-cloning.

| Tree | Pin | Lint (after → r2 → **r3**) |
|------|-----|------------------------------|
| **Newtonsoft.Json** | not recorded | **38 → 33 → 3** (cs-regex-in-loop) |
| **serilog** | not recorded | **3 → 1 → 0** |
| **Humanizer** | not recorded | **24 → 3 → 0** |

## G3 TP/FP triage (2026-10-22 Asia/Shanghai)

| Stage | n sample | TP | FP+DOC+SKIP | corpus-ready? |
|-------|----------|----|-------------|----------------|
| after/r1 | 65 | 0% | 21.5% | **no** |
| r2 | 37 | 0% | 0% | **no** (OK-idiom) |
| **r3** (cs-regex-in-loop) | **3** | **100%** | **0%** | **yes** |

r2→r3: demote cs-list-add-no-capacity–cs-console-in-loop → **off**; add **cs-regex-in-loop** (hint). No G4 JSONL.

## 2026-10-23 — new hint rules, not triaged

These slugs are **hint**. They have not been through G2/G3. Pin totals above do not include them. The 2026-10-22 corpus-ready verdict does not cover them.

- `cs-linq-materialize-in-loop`, `cs-format-in-loop` — wall-clock JSONL is on disk; default stays hint
- `cs-json-in-loop` — JSONL for one fixed payload (about 1500×); a changing payload cannot be hoisted; still hint
