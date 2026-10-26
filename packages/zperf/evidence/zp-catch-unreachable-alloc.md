# zp-catch-unreachable-alloc — N/A (correctness)

## Status

**N/A (correctness)** — no `evidence/zp-catch-unreachable-alloc.jsonl`. Do not invent one.

## Reason

`catch unreachable` on allocation is **UB on OOM**, not a throughput optimization.

## Why no JSONL

Correctness / safety, not speed.

## Unblock

None for a speed gate. The rule is currently **off**, so the CLI does not report it.
