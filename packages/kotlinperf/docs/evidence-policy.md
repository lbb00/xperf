# kotlinperf evidence policy

## Gate

A rule may be treated as **`error`** only with `evidence/<RULE>.md` + `.jsonl` **and** an explicit policy decision. Measured JSONL alone does **not** auto-escalate. Batch B (2026-10-22) kept package defaults.

## Current map

As of 2026-10-22 (Batch B G4).

| Rule | Severity (default) | Evidence | Smell |
|------|--------------------|----------|-------|
| kt-list-add-in-loop | off | **yes** ~2.1× | ArrayList empty vs cap |
| kt-string-plus-in-loop | off | **yes** ~1170× | string += |
| kt-println-in-loop | off | **yes** ~99× | println |
| KT004 | removed | tombstone | see `evidence/_removed/` |
