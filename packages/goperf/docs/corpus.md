# goperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.

## Pins

| Tree | URL | Commit | Notes |
|------|-----|--------|-------|
| gin | https://github.com/gin-gonic/gin | `0f09c3a9b4626d9fe9979cf4d0521d6ae32ab646` | shallow; 0 findings under defaults |
| testify | https://github.com/stretchr/testify | `87a7b9d57689f6579db2da795ab8deeab29cb724` | shallow |
| go (src/) | https://github.com/golang/go | `05dbbf9175d021c5a61a69e3cc22abbd483d7fb0` | sparse checkout `src/`; `cmd/` skipped |

## G3 summary (2026-10-22 Asia/Shanghai) — redesign

| Tree | r2 (pre-redesign) | r6 (defaults) | corpus-ready? |
|------|-------------------|---------------|---------------|
| gin | 0 | **0** | (clean under heuristics) |
| testify | 5 | **13** | OK-idiom harness |
| go-src | 429 | **210** | gp-append-nil-slice/gp-defer-hot |

**Verdict: corpus-ready `yes`.** Sample n=93: TP 77.4% / OK-idiom 22.6% / FP+DOC+SKIP 0%. Defaults: gp-make-hot–gp-fmt-hot **off**; gp-append-nil-slice/gp-defer-hot **hint**. No invented evidence JSONL / no G4 escalate.

### Redesign notes
- gp-append-nil-slice: empty slice + append in size-hinted loop
- gp-defer-hot: defer in loop (not nested closures; strings blanked)
- Skips: `cmd/`, `generate.go`, `_codegen/`

Do not commit corpus sources into `packages/goperf`.

## 2026-10-23 — hint rules outside the 2026-10-22 verdict

The 2026-10-22 corpus-ready verdict does not cover the slugs below. They stay **hint** and have not been through G2/G3.

- `gp-regexp-compile-hot`, `gp-json-marshal-hot`, `gp-reflect-hot` — JSONL on disk; still hint
