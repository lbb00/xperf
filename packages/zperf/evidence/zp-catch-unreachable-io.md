# zp-catch-unreachable-io — N/A (correctness)

## Status

**N/A (correctness)** — no `evidence/zp-catch-unreachable-io.jsonl`. Do not invent one.

## Reason

`catch unreachable` on I/O is **UB / crash on error**, not a speed win.

## Why no JSONL

Correctness / error handling, not wall-clock.

## Unblock

None for a speed gate. The rule is currently **off**, so the CLI does not report it.
