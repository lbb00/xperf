# zp-missing-free — N/A (correctness)

## Status

**N/A (correctness)** — no `evidence/zp-missing-free.jsonl`. Do not invent one.

## Reason

Missing `free` / `deinit` is a **leak / UB** smell. The win is correctness and resource hygiene, not a reproducible wall-clock improvement.

## Why no JSONL

Speed before/after does not define the rule’s value; leak detection does.

## Unblock

None for a speed gate. The rule is currently **off**, so the CLI does not report it.
