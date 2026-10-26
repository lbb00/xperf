# zp-packable-bools — pending measure

## Status

**pending measure** — no `evidence/zp-packable-bools.jsonl` yet.

## Reason

Packable bools / bit packing is a **layout density** claim. This pass did not land a bandwidth- or cache-sensitive harness that honestly shows wall-clock from packing alone.

## Why no JSONL

Density without a committed memory-traffic bench is not a speed gate.

## Unblock

SoA / bitset-style walk over a large working set (or known-good zp-bool-array-style bitset harness scoped to zp-packable-bools’s pattern), then JSONL. Until then the rule stays **off**.
