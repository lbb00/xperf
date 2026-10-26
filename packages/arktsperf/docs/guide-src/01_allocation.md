## 1. Allocation

Object / array literals and `new` inside tight UI or animation loops increase GC pressure. Reuse buffers when profiles show pressure.

Companion lint: **at-alloc-in-loop**.

