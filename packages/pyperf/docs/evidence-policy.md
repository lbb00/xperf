# pyperf evidence policy

## Gate

A rule may be **`error`** only with both `evidence/<RULE>.md` and measured `evidence/<RULE>.jsonl`.

## Current map

As of 2026-10-22.

| Rule | Severity | Evidence | Smell |
|------|----------|----------|-------|
| pp-str-plus-in-loop | **off** | measured (`pp-str-plus-in-loop.md` + `pp-str-plus-in-loop.jsonl`); kept off | string `+=` in loop (G3 OK-idiom) |
| pp-list-plus-rebind | hint | measured (`pp-list-plus-rebind.md` + `pp-list-plus-rebind.jsonl`); kept hint | list `+` rebinding in loop |
| pp-print-in-loop | **off** | measured (`pp-print-in-loop.md` + `pp-print-in-loop.jsonl`); kept off | `print(` in loop (G3 CLI) |
| pp-json-in-loop | hint | measured (`pp-json-in-loop.md` + `pp-json-in-loop.jsonl`); stay hint | `json.loads` / `dumps` in loop |
| pp-deepcopy-in-loop | hint | measured (`pp-deepcopy-in-loop.md` + `pp-deepcopy-in-loop.jsonl`); stay hint | `deepcopy` in loop |
| pp-open-in-loop | hint | measured (`pp-open-in-loop.md` + `pp-open-in-loop.jsonl`); stay hint | `open` in a loop; same path only; not corpus-triaged |
| PP004 | removed | tombstone | see `evidence/_removed/` |

Measured JSONL exists for the 2026-10-22 rules, but none is escalated: pp-str-plus-in-loop/pp-print-in-loop stay `off` (G3: OK-idiom in CLI and builder code) and pp-list-plus-rebind stays **hint**. PP004 is removed; its tombstone is under `evidence/_removed/`. `pp-regex-compile-in-loop` and `pp-datetime-format-in-loop` were removed.
