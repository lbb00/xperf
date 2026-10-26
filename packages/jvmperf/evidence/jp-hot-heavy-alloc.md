# jp-hot-heavy-alloc — pending measure

## Status

**pending measure** — no `evidence/jp-hot-heavy-alloc.jsonl` on this machine.

## Reason

Hot-path heavy alloc on Android `onDraw` / similar — needs ART/device + fair frame harness.

## Policy

Default severity **off** (run it with `--enable`). Do not escalate to error without honest before/after on the right runtime.
