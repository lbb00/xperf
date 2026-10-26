# swiftperf evidence policy

## Gate

A rule may be treated as **`error`** only with `evidence/<RULE>.md` + `.jsonl` **and** an explicit policy decision. Measured JSONL alone does **not** auto-escalate. Batch B (2026-10-22) kept package defaults.

## Current map

As of 2026-10-22, Batch B G4.

| Rule | Severity (default) | Evidence | Smell |
|------|--------------------|----------|-------|
| sp-print-in-loop | off | [sp-print-in-loop.md](../evidence/sp-print-in-loop.md) | about 10× versus a String, stdout at /dev/null; stays off |
| sp-array-no-reserve | hint | [sp-array-no-reserve.md](../evidence/sp-array-no-reserve.md) | about 5× on many small arrays; about 1.6× on one large fill; stay hint |
| sp-dateformatter-in-loop | hint | JSONL present (`sp-dateformatter-in-loop.md` + `.jsonl`); stays hint | date formatter constructed in a loop; not corpus-triaged |
| sp-json-decode-in-loop | hint | JSONL present (`sp-json-decode-in-loop.md` + `.jsonl`); stays hint | JSON decoder or jsonObject in a loop; not corpus-triaged |
| sp-regex-in-loop | hint | JSONL present (`sp-regex-in-loop.md` + `.jsonl`); stays hint | regular expression constructed in a loop; not corpus-triaged |
| sp-file-read-in-loop | hint | measured (`sp-file-read-in-loop.md` + `sp-file-read-in-loop.jsonl`); stay hint | `contentsOfFile` in a loop; same path only; not corpus-triaged |
| sp-clock-in-loop | hint | measured (`sp-clock-in-loop.md` + `sp-clock-in-loop.jsonl`); stay hint | `Date()` in a loop; not corpus-triaged |
| sp-value-for-key-in-loop | hint | measured (`sp-value-for-key-in-loop.md` + `sp-value-for-key-in-loop.jsonl`); stay hint | `value(forKey:)` in a loop; not corpus-triaged |

The three rows added 2026-10-23 stay **hint**. Each now has a JSONL microbench. They are outside the 2026-10-22 corpus-ready verdict, and the ratio is one shape, not a general speedup.
