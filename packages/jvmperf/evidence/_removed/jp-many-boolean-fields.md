# jp-many-boolean-fields — many boolean fields

## Claim

Packing many `boolean` fields into a bitfield can shrink instances **when** headers/alignment leave waste. Under **Compact Object Headers** on JDK 25, **8 booleans** and an `int` flags field both measure **16 bytes** — no footprint win for this shape.

## How measured

- Harness: `research/Jp009BoolPackJol.java` + JOL 0.17
- Raw: `JP009_BoolPackJol.jsonl`

## Runtime

| Shape | total_size_bytes (COH) |
|-------|------------------------|
| ManyBool (8× boolean) | **16** |
| Packed (int flags) | **16** |
| ratio | **1.0×** (no win) |

## Policy

**hint** — footprint claim is situational (Shipilev U-only / many instances / pre-COH). Do not escalate.

## Limits

Not a hot-path wall-clock claim. Few-instance types (Activity, Options, Server) already demoted.
