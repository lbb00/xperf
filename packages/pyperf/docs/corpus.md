# pyperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.

This package is **XPerf’s Python smell kit**, not the PyPI `pyperf` benchmark runner.

## Pins

| Tree | URL | Commit | Notes |
|------|-----|--------|-------|
| django | https://github.com/django/django | `3d3d943b7442f1f5278ed876331a06047fa96ea8` | shallow |
| flask | https://github.com/pallets/flask | `d086db856be187255b8ec61ef409357393020f32` | shallow |
| requests | https://github.com/psf/requests | `611c6162cbc4ac2020a2f91c7cfa4f3abf9bbb60` | shallow; 0 under defaults |

## G3 summary (2026-10-22 Asia/Shanghai) — redesign

| Tree | r2 | r3 (defaults) | corpus-ready? |
|------|----|---------------|---------------|
| django | 27 | **28** | PP004 |
| flask | 0 | **1** | CLI OK-idiom |
| requests | 0 | **0** | clean |

**Verdict: corpus-ready `yes`.** Sample n=29: TP 51.7% / OK-idiom 48.3% / FP+DOC+SKIP 0%. Defaults: pp-str-plus-hot/pp-print-hot **off**; pp-list-plus-rebind **hint**. PP004 removed (jitter). Measured JSONL fills exist but do not change the defaults (see [evidence-policy.md](evidence-policy.md)).

### Redesign notes

- PP004: ad-hoc `re.METHOD(literal)` inside functions
- Skips: `scripts/`, `management/commands/`

Do not commit corpus sources into `packages/pyperf`.

## 2026-10-23 — hint rules outside the 2026-10-22 verdict

The 2026-10-22 corpus-ready verdict does not cover the slugs below. They stay **hint** and have not been through G2/G3.

- `pp-json-hot`, `pp-deepcopy-hot` — JSONL on disk; still hint

`pp-regex-compile-in-loop` and `pp-datetime-format-in-loop` were removed. See `evidence/_removed/`. They are not part of that verdict.
