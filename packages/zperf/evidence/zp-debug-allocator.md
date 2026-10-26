# zp-debug-allocator — N/A (static-only)

## Status

**N/A (static-only)** — no `evidence/zp-debug-allocator.jsonl`. Do not invent one.

## Reason

Rule flags GPA / arena / FBA selection that depends on **build mode** (Debug vs Release*). There is no single-binary before/after wall-clock pair: the “fix” is choosing a different allocator at compile time, not a hot-path rewrite inside one executable.

## Why no JSONL

Wall-clock evidence assumes same optimize mode and comparable ops. Mode-switch smells are review prompts, not speed gates.

## Unblock

None for a speed gate. Keep as static review; document preferred allocator per mode in the guide if needed.
