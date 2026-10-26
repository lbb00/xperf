## Strings

On Nim 2.2.12, `-d:release`, `&=` of 20000 pieces was faster than `newSeq` plus `join` (about 0.79×). The lint that suggested `join` was removed. See `evidence/_removed/nm-string-amp-in-loop.REMOVED.md`.

