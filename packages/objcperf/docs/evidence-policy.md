# objcperf evidence policy

## Gate

A rule may be treated as **`error`** only with `evidence/<RULE>.md` + `.jsonl` **and** an explicit policy decision. Measured JSONL alone does **not** auto-escalate. The 2026-10-22 G4 fill kept package defaults.

## Current map

As of 2026-10-23. Measured rows are the 2026-10-22 G4 fill. The three new slugs are hint, pending, and not corpus-triaged.

| Rule | Severity (default) | Evidence | Smell |
|------|--------------------|----------|-------|
| oc-nsstring-append-hot | off | **yes** GNUstep ~569× | NSString append |
| oc-nslog-hot | off | **yes** fprintf proxy ~191× | log in loop |
| oc-dateformatter-hot | hint | measured (`oc-dateformatter-hot.md` + `oc-dateformatter-hot.jsonl`); stay hint | date formatter alloc/init or new in a loop; not corpus-triaged |
| oc-json-hot | hint | measured (`oc-json-hot.md` + `oc-json-hot.jsonl`); stay hint | JSON parse or encode in a loop; not corpus-triaged |
| oc-regex-hot | hint | measured (`oc-regex-hot.md` + `oc-regex-hot.jsonl`); stay hint | regular expression compiled in a loop; not corpus-triaged |
| oc-file-read-hot | hint | measured (`oc-file-read-hot.md` + `oc-file-read-hot.jsonl`); stay hint | `stringWithContentsOfFile` in a loop; same path only; not corpus-triaged |
| oc-clock-hot | hint | measured (`oc-clock-hot.md` + `oc-clock-hot.jsonl`); stay hint | `[NSDate date]` in a loop; not corpus-triaged |
| oc-value-for-key-hot | hint | measured (`oc-value-for-key-hot.md` + `oc-value-for-key-hot.jsonl`); stay hint | `valueForKey:` in a loop; not corpus-triaged |
| OC001 | removed | tombstone | see `evidence/_removed/` |
| OC004 | removed | tombstone | see `evidence/_removed/` |
