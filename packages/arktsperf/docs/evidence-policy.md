# arktsperf evidence policy

## Gate

A rule may be treated as **`error`** only with `evidence/<slug>.md` + `.jsonl` **and** a preferred ArkTS/device runtime bench. A **Node proxy** alone keeps **`hint`** / package default (say so in the md).

## Current map

As of 2026-10-22 (Batch B).

| Rule | Severity | Evidence | Smell |
|------|----------|----------|-------|
| at-alloc-hot | off | Node proxy JSONL (~33×) | allocation-like in loop |
| at-console-hot | off | Node proxy JSONL (~208×) | console in loop |
| at-includes-hot | hint | Node proxy JSONL (~29× includes→Set) | indexOf/includes in loop |
| at-json-hot | hint | Node proxy JSONL (~2× JSON) | JSON.parse/stringify in loop |

No severity escalate from Node proxy alone.
