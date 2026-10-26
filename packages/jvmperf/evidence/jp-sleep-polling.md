# jp-sleep-polling — pending measure

## Status

**pending measure** — no `evidence/jp-sleep-polling.jsonl` on this machine.

## Reason

`Thread.sleep` polling — wall-clock is dominated by the sleep itself; replacing with park/condition is correctness/latency design, not a micro ratio we can honestly gate as error.

## Policy

Default severity **off** (run it with `--enable`). Do not escalate to error without honest before/after on the right runtime.
