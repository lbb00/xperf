# jp-finalize — pending measure

## Status

**pending measure** — no `evidence/jp-finalize.jsonl` on this machine.

## Reason

`finalize()` — correctness / GC latency smell; Shipilev and JDK deprecate it. No fair before/after speed micro (Cleaner is the fix). Pending measure as wall-clock gate.

## Policy

Stays **hint** / review. Do not escalate to error without honest before/after on the right runtime.
