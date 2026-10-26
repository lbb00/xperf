# Nim performance guide (v0)

Assembled from `docs/guide-src/`. Scaffold — not a measured handbook. Heuristic kit — measure before escalating lint to error.

## Sequences

Prefer `newSeqOfCap` / `setLen` + index writes when the length or iteration count is known. Repeated `.add` in hot loops reallocates. Companion: **nm-seq-no-capacity**.

## Strings

On Nim 2.2.12, `-d:release`, `&=` of 20000 pieces was faster than `newSeq` plus `join` (about 0.79×). The lint that suggested `join` was removed. See `evidence/_removed/nm-string-amp-in-loop.REMOVED.md`.

## IO

Keep `echo` out of hot loops; gate or buffer.

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| nm-seq-add-in-loop | seq `.add` in loop | off (G3) |
| nm-echo-in-loop | `echo` in loop | off (G3) |
| nm-seq-no-capacity | empty seq + `.add` size-hinted | hint |

## See also

Rule ids: [rule-ids.md](rule-ids.md). Evidence policy: [evidence-policy.md](evidence-policy.md). Process gates: root [AGENT.md](../../../AGENT.md).
