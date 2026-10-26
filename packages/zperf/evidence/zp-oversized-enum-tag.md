# zp-oversized-enum-tag — N/A (static size)

## Status

**N/A (static size)** — no `evidence/zp-oversized-enum-tag.jsonl`. Do not invent one.

## Reason

Oversized enum tag is an **ABI / size** smell (`@sizeOf`). Wall-clock is the wrong gate.

## Why no JSONL

Static size comparison is the evidence; microbench would be theatre.

## Unblock

Optional: document `@sizeOf` before/after in the md if useful for teaching — still no JSONL speed gate. The rule stays **off**.
