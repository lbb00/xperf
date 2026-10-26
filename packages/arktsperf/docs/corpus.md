# arktsperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.

## Pins

As of 2026-10-22 (Asia/Shanghai); real ArkTS trees.

| Tree | Commit / source | Lint r2 → r3 redesign | Notes |
|------|-----------------|----------------------|-------|
| **BasicFeature** | gitee `openharmony/applications_app_samples` `a826ab0e` `code/BasicFeature` | 29 → **22** | at-includes-in-loop, at-json-in-loop |
| **UI** | same repo `code/UI` | 13 → **8** | at-includes-in-loop |
| **dimina-harmony** | local Harmony/ArkTS tree (not vendored; pin URL+commit when published) @ `cfd73f9914da1f417a4f1af62fa08b7642548f5d` | 6 → **26** | BASE64 at-includes-in-loop TP |

**corpus-ready: yes** (r3 redesign). Defaults: `at-includes-in-loop` and `at-json-in-loop` **hint**; the other three rules **off**. No G4.

Do not commit corpus sources into `packages/arktsperf`.
