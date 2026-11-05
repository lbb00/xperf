## 1. Sequences

Prefer `newSeqOfCap` / `setLen` + index writes when the length or iteration count is known. Repeated `.add` in hot loops reallocates.

Lint: `nm-seq-add-hot` (default off after G3); `nm-seq-no-capacity` (empty seq + `.add` size-hinted; default hint).

