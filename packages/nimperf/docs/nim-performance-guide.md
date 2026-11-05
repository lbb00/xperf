# Nim performance guide (v0)

Assembled from `docs/guide-src/`. Scaffold checklist — not a measured handbook. Measure before escalating lint to error.

> **Scope: Nim (heuristic kit).** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

## Contents

- [1. Sequences](#1-sequences)
- [2. Strings](#2-strings)
- [3. I/O](#3-io)
- [Lint map](#lint-map)

## 1. Sequences

Prefer `newSeqOfCap` / `setLen` + index writes when the length or iteration count is known. Repeated `.add` in hot loops reallocates.

Lint: `nm-seq-add-hot` (default off after G3); `nm-seq-no-capacity` (empty seq + `.add` size-hinted; default hint).

## 2. Strings

On Nim 2.2.12, `-d:release`, `&=` of 20000 pieces was faster than `newSeq` plus `join` (about 0.79×). The lint that suggested `join` was removed. See `evidence/_removed/nm-string-amp-in-loop.REMOVED.md`.

## 3. I/O

Keep `echo` out of hot loops; gate or buffer.

Lint: `nm-echo-hot` (default off after G3).

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| nm-seq-add-hot | seq `.add` in loop | off (G3) |
| nm-echo-hot | `echo` in loop | off (G3) |
| nm-seq-no-capacity | empty seq + `.add` size-hinted | hint |

## See also

Rule ids: [rule-ids.md](rule-ids.md). Evidence policy: [evidence-policy.md](evidence-policy.md). Process gates: root [AGENT.md](../../../AGENT.md).
