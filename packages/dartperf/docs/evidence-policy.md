# dartperf evidence policy

## Gate

A rule may be treated as **`error`** only with `evidence/<RULE>.md` + `.jsonl` **and** an explicit policy decision. Measured JSONL alone does **not** auto-escalate. Batch B (2026-10-22) kept package defaults.

## Current map

As of 2026-10-22 (Batch B G4).

| Rule | Severity (default) | Evidence | Smell |
|------|--------------------|----------|-------|
| dt-list-add-empty | off | **yes** ~3.1× | empty List + add |
| dt-string-plus-in-loop | off | **yes** ~247× | string + |
| dt-print-in-loop | off | **yes** ~128× | print/write |
| dt-growable-add-empty | hint | **yes** ~2.4× | empty + add sized |
