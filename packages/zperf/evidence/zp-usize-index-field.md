# zp-usize-index-field — pending measure

## Status

**pending measure** — no `evidence/zp-usize-index-field.jsonl` yet.

## Reason

`usize` index fields that could be narrower are a **layout density / ABI** smell. No wall-clock bandwidth harness was committed this pass.

## Why no JSONL

Size/density without traffic measurement is not a speed gate.

## Unblock

Struct-array walk where narrowing index fields changes line density enough to move median wall-clock; then JSONL. Until then the rule stays **off**.
