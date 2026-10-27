## 1. Allocation

Prefer reusing buffers (`sync.Pool`, pre-sized slices) over `make`/`new` inside tight loops when profiles show alloc pressure. Escape analysis may keep small values on the stack — **do not** rewrite without a bench.

Companion lint: **gp-make-hot** (off after G3), **gp-append-nil-slice** (empty slice + append in size-hinted loop).

