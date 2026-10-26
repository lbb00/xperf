# objcperf evidence policy

## Gate

A rule may be treated as **`error`** only with `evidence/<RULE>.md` + `.jsonl` **and** an explicit policy decision. Measured JSONL alone does **not** auto-escalate. The 2026-10-22 G4 fill kept package defaults.

## Current map

As of 2026-10-23. Measured rows are the 2026-10-22 G4 fill. The three new slugs are hint, pending, and not corpus-triaged.

| Rule | Severity (default) | Evidence | Smell |
|------|--------------------|----------|-------|
| oc-nsstring-append-in-loop | off | **yes** GNUstep ~569× | NSString append |
| oc-nslog-in-loop | off | **yes** fprintf proxy ~191× | log in loop |
| oc-dateformatter-in-loop | hint | measured (`oc-dateformatter-in-loop.md` + `oc-dateformatter-in-loop.jsonl`); stay hint | date formatter alloc/init or new in a loop; not corpus-triaged |
| oc-json-in-loop | hint | measured (`oc-json-in-loop.md` + `oc-json-in-loop.jsonl`); stay hint | JSON parse or encode in a loop; not corpus-triaged |
| oc-regex-in-loop | hint | measured (`oc-regex-in-loop.md` + `oc-regex-in-loop.jsonl`); stay hint | regular expression compiled in a loop; not corpus-triaged |
| oc-file-read-in-loop | hint | measured (`oc-file-read-in-loop.md` + `oc-file-read-in-loop.jsonl`); stay hint | `stringWithContentsOfFile` in a loop; same path only; not corpus-triaged |
| oc-clock-in-loop | hint | measured (`oc-clock-in-loop.md` + `oc-clock-in-loop.jsonl`); stay hint | `[NSDate date]` in a loop; not corpus-triaged |
| oc-value-for-key-in-loop | hint | measured (`oc-value-for-key-in-loop.md` + `oc-value-for-key-in-loop.jsonl`); stay hint | `valueForKey:` in a loop; not corpus-triaged |
| OC001 | removed | tombstone | see `evidence/_removed/` |
| OC004 | removed | tombstone | see `evidence/_removed/` |
