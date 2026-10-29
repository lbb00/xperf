# goperf evidence policy

## Gate

A rule may be treated as **`error`** only if both exist under `packages/goperf/evidence/`:

1. `<RULE>.md` — claim, how measured, `go` version / flags, limits
2. `<RULE>.jsonl` — ≥1 before/after line with `rule`, `case`, `median_ns` (or `median_ms`), `ops`, `ratio`, `ts`

Otherwise the rule stays **`hint`** (or **`off`** after G3 OK-idiom demotion).

## Current map

As of 2026-10-22.

| Rule | Severity | Evidence | Smell |
|------|----------|----------|-------|
| gp-make-hot | **off** | **yes** ~265× | `make`/`new` in loop (G3 OK-idiom) |
| gp-string-plus-hot | **off** | **yes** ~2919× | string `+=` in loop (G3 OK-idiom) |
| gp-fmt-hot | **off** | **yes** ~2.8× | `fmt.*printf` in loop (G3 OK-idiom) |
| gp-append-nil-slice | hint | **yes** ~12.2× | empty slice + append in size-hinted loop |
| gp-defer-hot | hint | **yes** ~33× | `defer` in loop |
| gp-regexp-compile-hot | hint | measured (`gp-regexp-compile-hot.md` + `gp-regexp-compile-hot.jsonl`); stay hint | `regexp.Compile` in loop; not corpus-triaged |
| gp-json-marshal-hot | hint | measured (`gp-json-marshal-hot.md` + `gp-json-marshal-hot.jsonl`); stay hint | `json.Marshal` / `Unmarshal` in loop; not corpus-triaged |
| gp-reflect-hot | hint | measured (`gp-reflect-hot.md` + `gp-reflect-hot.jsonl`); stay hint | `FieldByName` / `MethodByName` / `reflect.New` in loop; `TypeOf` is not matched; not corpus-triaged |
| gp-os-open-hot | hint | measured (`gp-os-open-hot.md` + `gp-os-open-hot.jsonl`); stay hint | `os.Open` in a loop; same path only; not corpus-triaged |
| gp-time-now-hot | hint | measured (`gp-time-now-hot.md` + `gp-time-now-hot.jsonl`); stay hint | `time.Now` in a loop; not `time.Parse`; not corpus-triaged |

Measured `.md` + `.jsonl` exist for all five rules, but none auto-escalates: gp-append-nil-slice/gp-defer-hot stay **hint** and the three demoted rules stay **off** (G3 OK-idiom history). Re-enable demoted rules with `--severity <rule>=hint` (for example `--severity gp-make-hot=hint`).
