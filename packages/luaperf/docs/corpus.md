# luaperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.

## Pins

Shallow clones.

| Tree | Commit | Size |
|------|--------|------|
| **kong** | `2103212` | 31M |
| **apisix** | `016dcd0` | 51M |
| **lua-resty-core** | `873d072` | 2.8M |

Lint with:

```sh
lua5.4 packages/luaperf/luaperf-lint/luaperf-lint.lua \
  <corpus-dir>/<name> --format json --no-fail
```

Checker is **Lua 5.4** (`luaperf-lint`). Rules lu-table-insert-hot–lu-print-hot (**lu-table-insert-hot default `off`**; **lu-string-concat-hot default `error`** with G4; lu-print-hot `hint` with G4).

## Dogfood: G3 r2 and post-G4 r3 (2026-10-21 to 2026-10-22, Asia/Shanghai)

| Tree | baseline → r1 → r2 → **r3** |
|------|------------------------------|
| **kong** | 2475 → 75 → 19 → **11** (lu-string-concat-hot:10 lu-print-hot:1) |
| **apisix** | 560 → 198 → 26 → **23** (lu-string-concat-hot:23) |
| **lua-resty-core** | 13 → 0 → 0 → **0** |

**corpus-ready: yes** — r3 sample n=34: TP 73.5%, FP+DOC+SKIP 2.9%; honest TP on lu-string-concat-hot; lu-string-concat-hot error has G4 (`evidence/lu-string-concat-hot.md`+`jsonl`). lu-print-hot has measured evidence but stays hint.

### Reverse-opt

- Path skips: `spec/` `t/` `test(s)/` `example(s)/` `docs/` `benchmark(s)/` `.ci/` `autodoc/` `fixtures/` `vendor/` `cli/` `bin/` `scripts/`
- **lu-table-insert-hot default `off`** — OpenResty/Lua `table.insert` collect idiom
- lu-string-concat-hot: accumulation only with **ident boundary** (no mid-ident `key` match inside `ineligible_key`)
- lu-print-hot: bare `print(` only (not `buffered_print` / `ngx_print`)

Do not commit corpus sources into `packages/luaperf`.
