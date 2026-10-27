# rubyperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.

```sh
ruby packages/rubyperf/rubyperf-lint/rubyperf-lint.rb <corpus-dir>/<name> --format json --no-fail
```

Checker: `rubyperf-lint`. The 2026-10-22 triage covered rb-string-plus-hot–rb-hash-merge-in-loop. `rb-hash-merge-in-loop` was removed on 2026-10-23.

## Pins

Shallow clones of the upstream default branches; commits were not recorded.

| Tree | URL |
|------|-----|
| rails (ActiveSupport + ActiveRecord) | https://github.com/rails/rails |
| jekyll | https://github.com/jekyll/jekyll |
| sidekiq | https://github.com/sidekiq/sidekiq |

## Lint counts — after → r2 → r3 (redesign)

| Tree | Lint (after → r2 → **r3**) |
|------|------------------------------|
| **rails** AS+AR | **4 → 1 → 2** (rb-hash-merge-in-loop) |
| **jekyll** | **0 → 0 → 0** |
| **sidekiq** | **5 → 0 → 2** (rb-hash-merge-in-loop) |

## G3 TP/FP triage (2026-10-22 Asia/Shanghai)

| Stage | n sample | TP | FP+DOC+SKIP | corpus-ready? |
|-------|----------|----|-------------|----------------|
| after/r1 | 9 | 0% | 33.3% | **no** |
| r2 | 1 | 0% | 0% | **no** (OK-idiom) |
| **r3** (rb-hash-merge-in-loop) | **4** | **75%** | **0%** | **yes** |

r2→r3: demote rb-string-plus-hot–rb-puts-hot → **off**; add **rb-hash-merge-in-loop** (hint). Measured G4 evidence: see [evidence-policy.md](evidence-policy.md).

## 2026-10-23 — hint rules outside the 2026-10-22 verdict

The 2026-10-22 corpus-ready verdict does not cover the slugs below. They stay **hint** and have not been through G2/G3.

- `rb-regexp-new-hot`, `rb-json-hot` — JSONL on disk; still hint
