## Sequences

Prefer `newSeqOfCap` / `setLen` + index writes when the length or iteration count is known. Repeated `.add` in hot loops reallocates. Companion: **nm-seq-no-capacity**.

