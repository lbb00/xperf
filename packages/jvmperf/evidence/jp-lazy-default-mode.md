# jp-lazy-default-mode — pending measure

## Status

**pending measure** — no `evidence/jp-lazy-default-mode.jsonl` on this machine.

## Reason

Kotlin `by lazy` default mode (SYNCHRONIZED) is situational — measure only when contention or init cost is profiled. No honest micro that generalizes; stays pending.

## Policy

Default severity **off** (run it with `--enable`). Do not escalate to error without honest before/after on the right runtime.
