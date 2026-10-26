# zp-broad-runtime-safety — pending measure

## Status

**pending measure** — no `evidence/zp-broad-runtime-safety.jsonl` yet.

## Reason

Broad `@setRuntimeSafety(false)` only has a meaningful wall-clock story under **ReleaseSafe** (where safety checks still run). This pass’s harness was `-Ofast` / ReleaseFast-shaped and did not commit a ReleaseSafe pair.

## Why no JSONL

Wrong optimize mode would understate or invent a win.

## Unblock

Dedicated ReleaseSafe before/after in `evidence_fill.zig` (or sibling), median≥9, then add `.jsonl` + update this md. Until then keep warning / review.
