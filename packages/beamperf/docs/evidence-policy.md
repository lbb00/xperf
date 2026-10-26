# beamperf evidence policy

## Gate

A rule may be treated as **`error`** only with `evidence/<slug>.md` + `.jsonl` **and** an explicit policy decision. Measured JSONL alone does **not** auto-escalate. Batch B (2026-10-22) kept package defaults.

## Current map

As of 2026-10-22 (Batch B G4).

| Rule | Severity (default) | Evidence | Smell |
|------|--------------------|----------|-------|
| be-list-concat-reduce | hint | **yes** ~453× | list ++ |
| be-io-puts-in-loop | off | **yes** ~3810× | IO in loop |
| be-map-merge-in-loop | hint | **yes** ~6.9× merge vs put | Map/Keyword.merge |
| be-enum-map-filter-chain | hint | **yes** ~4.5× map then filter | Enum chain |

Removed (tombstone): `BE002` (binary `<>`), see `evidence/_removed/`.
