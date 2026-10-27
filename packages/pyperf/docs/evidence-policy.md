# pyperf evidence policy

## Gate

A rule may be **`error`** only with both `evidence/<RULE>.md` and measured `evidence/<RULE>.jsonl`.

## Current map

As of 2026-10-22.

| Rule | Severity | Evidence | Smell |
|------|----------|----------|-------|
| pp-str-plus-hot | **off** | measured (`pp-str-plus-hot.md` + `pp-str-plus-hot.jsonl`); kept off | string `+=` in loop (G3 OK-idiom) |
| pp-list-plus-rebind | hint | measured (`pp-list-plus-rebind.md` + `pp-list-plus-rebind.jsonl`); kept hint | list `+` rebinding in loop |
| pp-print-hot | **off** | measured (`pp-print-hot.md` + `pp-print-hot.jsonl`); kept off | `print(` in loop (G3 CLI) |
| pp-json-hot | hint | measured (`pp-json-hot.md` + `pp-json-hot.jsonl`); stay hint | `json.loads` / `dumps` in loop |
| pp-deepcopy-hot | hint | measured (`pp-deepcopy-hot.md` + `pp-deepcopy-hot.jsonl`); stay hint | `deepcopy` in loop |
| pp-open-hot | hint | measured (`pp-open-hot.md` + `pp-open-hot.jsonl`); stay hint | `open` in a loop; same path only; not corpus-triaged |
| PP004 | removed | tombstone | see `evidence/_removed/` |

Measured JSONL exists for the 2026-10-22 rules, but none is escalated: pp-str-plus-hot/pp-print-hot stay `off` (G3: OK-idiom in CLI and builder code) and pp-list-plus-rebind stays **hint**. PP004 is removed; its tombstone is under `evidence/_removed/`. `pp-regex-compile-in-loop` and `pp-datetime-format-in-loop` were removed.
